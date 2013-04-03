use strict;
use Data::Dumper;
use Carp;
use FileHandle;

sub incl {
    my $VAR;
    my $file = shift;
    local $/ = undef;
    my $fd = new FileHandle;
    open($fd,$file);
    my $c = <$fd>;
    close($fd);
    eval $c;
    return $VAR;
}

sub findall {
    my $name = shift;
    my $arg = shift;
    carp "die" unless(ref($arg) eq "HASH");
    if($arg->{name} =~ $name) {
        return [$arg];
    } else {
        my $ret = [];
        for my $child (@{$arg->{children}}) {
            push @$ret, @{findall($name,$child)};
        }
        return $ret;
    }
    return [];
}

sub gettext {
    my $arg = shift;
    if(defined($arg->{text})) {
        return $arg->{text};
    } else {
        for my $child (@{$arg->{children}}) {
            my $ret = gettext($child);
            if(defined($ret)) {
                return $ret;
            }
        }
    }
    return "";
}


sub needs_update {
    my $target_file = shift;
    unless(-r $target_file) {
        return 1;
    }
    my @st = stat($target_file);
    for my $src_file (@_) {
        my @ss = stat($src_file);
        if($st[9] < $ss[9]) {
            return 1;
        }
    }
    return 0;
}

my %ensured_dirs = ();

sub ensure_dir {
    my $dir = shift;
    return if(defined($ensured_dirs{$dir}));
    if(-d $dir) {
        $ensured_dirs{$dir}++;
        return
    }
    if($dir =~ m{(.*)/}) {
        my $parent_dir = $1;
        ensure_dir($parent_dir);
    }
    die unless(mkdir($dir));
    $ensured_dirs{$dir}++;
}

sub cmd {
    my $cmd = shift;
    print "CMD: $cmd\n";
    my $rc = system($cmd);
    die $cmd if($rc);
}

my $cctk_home = $ARGV[0];
my $configs = $ARGV[1];
die "usage: piraha-compile.pl config" unless(defined($cctk_home) and defined($configs));
my $thornlist = "$configs/ThornList";

my $td = new FileHandle;
open($td,$thornlist) or die "Cannot open $thornlist";
my $thorns = {};
while(<$td>) {
    if(/^(\w+)\/(\w+)/) {
        $thorns->{lc($1)}->{lc($2)}=1;
    }
}
$thorns->{cactus}->{cactus}=1;

my $piraha_dir = "$configs/piraha";
my $peg_dir = "$cctk_home/src/piraha/pegs";
my $interface_peg = "$peg_dir/interface.peg";

my %impls = ();
for my $ccl_file (<$cctk_home/arrangements/*/*/*.ccl>) {
    do_ccl_file($ccl_file);
}
for my $ccl_file (<$cctk_home/src/*.ccl>) {
    do_ccl_file($ccl_file);
}
sub do_ccl_file {
    my $ccl_file = shift;
    my $arrangement;
    my $thorn;
    my $lc_thorn;
    my $type;
    if($ccl_file =~ m{arrangements/([^/]*)/([^/]*)/([^\.]*)\.ccl}) {
        $arrangement = lc($1);
        $thorn = $2;
        $lc_thorn = lc($2);
        $type = lc($3);
    } elsif($ccl_file =~ m{src/([^\.]*)\.ccl}) {
        $arrangement = "cactus";
        $thorn = "Cactus";
        $lc_thorn = "cactus";
        $type = lc($1);
    } else {
        die "Cannot find ccl file\n";
    }
    next unless(defined($thorns->{$arrangement}->{$lc_thorn}));

    my $pm_dir = "${piraha_dir}/${type}s";
    my $pm_file = "${pm_dir}/${thorn}.pm";
    my $peg_file = "${peg_dir}/${type}.peg";
    die "Need $peg_file" unless(-r $peg_file);
    if(needs_update($pm_file,$ccl_file)) {
        ensure_dir($pm_dir);
        cmd("$configs/bin/generic --perl -o${pm_file} ${peg_file} ${ccl_file}");
    }
}
