#!/bin/sh
# vim: set noexpandtab:

set -e
set -x

# install path
NIX_PREFIX=`readlink -f $HOME` # path to nix store must not contain symlinks
MYTMP=/tmp/nix-boot-`whoami`
NUM_THREADS=4

export PATH=/bin:/usr/bin:/usr/sbin:/sbin
export LD_LIBRARY_PATH=""

if hostname | grep bnl\.gov; then
	export ftp_proxy="ftpgateway.sec.bnl.local:3128"
fi

rm -rf $MYTMP
mkdir $MYTMP
pushd $MYTMP

export PATH=$MYTMP/bin:$PATH
export LD_LIBRARY_PATH=$MYTMP/lib64:$MYTMP/lib:$LD_LIBRARY_PATH

function mmi () {
	make -j $NUM_THREADS 1> /dev/null
	make install 1> /dev/null
}

wget https://nixos.org/releases/nix/nix-1.11.7/nix-1.11.7.tar.xz
wget https://cpan.metacpan.org/authors/id/T/TI/TIMB/DBI-1.636.tar.gz --no-check-certificate
wget https://cpan.metacpan.org/authors/id/I/IS/ISHIGAKI/DBD-SQLite-1.54.tar.gz --no-check-certificate
wget https://cpan.metacpan.org/authors/id/S/SZ/SZBALINT/WWW-Curl-4.17.tar.gz --no-check-certificate
wget http://tukaani.org/xz/xz-5.2.3.tar.gz --no-check-certificate
wget https://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.xz
wget https://ftp.gnu.org/gnu/bison/bison-3.0.4.tar.xz
wget https://github.com/westes/flex/releases/download/v2.6.3/flex-2.6.3.tar.gz -O flex-2.6.3.tar.gz

tar Jxf nix-1.11.7.tar.xz
tar zxf DBI-1.636.tar.gz
tar zxf DBD-SQLite-1.54.tar.gz
tar zxf WWW-Curl-4.17.tar.gz
tar zxf xz-5.2.3.tar.gz
tar Jxf m4-1.4.18.tar.xz
tar Jxf bison-3.0.4.tar.xz
tar zxf flex-2.6.3.tar.gz

pushd WWW-Curl-4.17
perl Makefile.PL PREFIX=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd DBI-1.636
perl Makefile.PL PREFIX=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd DBD-SQLite-1.54
perl Makefile.PL PREFIX=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd xz-5.2.3
./configure --prefix=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd m4-1.4.18
./configure --prefix=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd bison-3.0.4
./configure --prefix=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd
pushd flex-2.6.3
./configure --prefix=$MYTMP 1>/dev/null 2>/dev/null
mmi
popd

AFS_GCC=/afs/rhic/rcassoft/x8664_sl6/gcc492
if [ -d "${AFS_GCC}" ]; then
	export PATH=${AFS_GCC}/bin:$PATH
	export LD_LIBRARY_PATH=${AFS_GCC}/lib64:$LD_LIBRARY_PATH
else
	wget https://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.bz2
	tar jxf gcc-4.9.2.tar.bz2
	# TODO add detection for when gcc is new enough (gcc49 is a minimal requirement)
	pushd gcc-4.9.2
	./contrib/download_prerequisites
	popd
	rm -rf gcc-objs || true
	mkdir -p gcc-objs
	pushd gcc-objs
	$PWD/../gcc-4.9.2/configure --prefix=$MYTMP --enable-languages=c,c++ --disable-multilib --disable-bootstrap 1>/dev/null 2>/dev/null
	mmi
	popd
fi

export PERL5OPT="-I$MYTMP/lib64/perl5"
pushd nix-1.11.7
export LDFLAGS="-L$MYTMP/lib -lpthread $LDFLAGS"
export GLOBAL_LDFLAGS="-lpthread"
sed -i "s,-llzma,-L$MYTMP/lib -llzma," src/libutil/local.mk
PKG_CONFIG_PATH=$MYTMP/lib/pkgconfig ./configure --prefix=$MYTMP --with-store-dir=$NIX_PREFIX/nix/store --localstatedir=$NIX_PREFIX/nix/var
mmi
popd

if [ ! -d ~/nixpkgs ]; then
	git clone https://github.com/NixOS/nixpkgs.git ~/nixpkgs
	pushd ~/nixpkgs
	git checkout release-17.03
	popd
fi

if [ ! -L ~/.nix-profile ]; then
	ln -s $NIX_PREFIX/nix/var/nix/profiles/default ~/.nix-profile
fi

if [ ! -d ~/.nixpkgs ]; then
	mkdir ~/.nixpkgs || true
	cat <<EOF > ~/.nixpkgs/config.nix
pkgs:
{
  packageOverrides = pkgs: {
    nix = pkgs.nix.override {
      storeDir = "$NIX_PREFIX/nix/store";
      stateDir = "$NIX_PREFIX/nix/var";
    };
  };
}
EOF

if hostname | grep bnl\.gov; then
	# http://pax.grsecurity.net is blocked by site firewall 
	nix-prefetch-url http://source.ipfire.org/source-2.x/paxctl-0.9.tar.gz
fi
# use nix to bootstrap stdenv and install proper nix
nix-env -Q -j $NUM_THREADS -i nix -f ~/nixpkgs

rm -rf $MYTMP
set +x

cat <<EOF


============================================

Add following to your shell rc file:

export NIX_PATH=nixpkgs=\$HOME/nixpkgs
source ~/.nix-profile/etc/profile.d/nix.sh

============================================

EOF
