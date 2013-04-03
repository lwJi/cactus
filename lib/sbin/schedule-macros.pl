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

my $cctk_home = $ARGV[0];
my $configs = $ARGV[1];
die "usage: macro.pl config" unless(defined($cctk_home) and defined($configs));
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
my $piraha_interfaces_dir = "$piraha_dir/interfaces";
my $piraha_schedules_dir = "$piraha_dir/schedules";
ensure_dir($piraha_dir);
ensure_dir($piraha_interfaces_dir);
ensure_dir($piraha_schedules_dir);

my %impl_to_interface_ccl = ();
my %impls = ();
for my $interface_pm (<$piraha_interfaces_dir/*.pm>) {
    my $parse_tree = incl($interface_pm);
    my $ccl_file = gettext(findall("annot:src_file",$parse_tree)->[0]);
    my ($arrangement,$thorn,$lc_thorn);
    if($ccl_file =~ m{arrangements/([^/]*)/([^/]*)/interface.ccl}) {
        $arrangement = lc($1);
        $thorn = $2;
        $lc_thorn = lc($2);
    } elsif($ccl_file =~ m{src/interface.ccl}) {
        $arrangement = "cactus";
        $thorn = "Cactus";
        $lc_thorn = "cactus";
    } else {
        die "Could not match file $ccl_file";
    }
    next unless(defined($thorns->{$arrangement}->{$lc_thorn}));

    my $impl = lc(gettext(findall("IMPLEMENTS",$parse_tree)->[0]));
    $impl_to_interface_ccl{$impl} = $ccl_file;

    for my $gvar (@{findall("GROUP_VARS",$parse_tree)}) {
        my @varnames = ();
        my $name = gettext(findall("name",$gvar)->[0]);
        my $gtype = lc(gettext(findall("gtype",$gvar)->[0]));
        my $vtype = lc(gettext(findall("vtype",$gvar)->[0]));
        my $vars = findall("parse_tree",$gvar)->[0];
        for my $nvar (@{findall("name",$gvar)}) {
            push @varnames, gettext($nvar);
        }
        # Tabulate scalars by interface
        if($gtype eq "scalar") {
            for my $varname (@varnames) {
                $impls{$impl}->{$varname} = $vtype;
            }
        }
    }
}
my @impls = keys %impls;

for my $schedule_file (<$piraha_schedules_dir/*.pm>) {
    die "Could not determine thorn"
        unless $schedule_file =~ m{([^/]+)\.pm$};
    my $thorn = $1;

    my $fd = new FileHandle;
    my $macro_dir="$configs/bindings/include/$thorn";
    ensure_dir($macro_dir);
    my $macro_file="$macro_dir/cctk_Macros.h";
    my $parse_tree = incl($schedule_file);
    my $schedule_ccl = gettext(findall("annot:src_file",$parse_tree)->[0]);
    next unless(defined($parse_tree));
    my $scheds = findall("schedule",$parse_tree);
    my $interface_file = $schedule_file;
    $interface_file =~ s{/schedules(/[^/]+\.pm$)}{/interfaces$1};
    die $interface_file unless(-r $interface_file);
    my $interface = incl($interface_file);
    my $impl = lc(gettext(findall("IMPLEMENTS",$interface)->[0]));
    my @impls = ($impl);
    for my $inherit (@{findall("INHERITS",$interface)->[0]->{children}}) {
        push @impls, lc(gettext($inherit));
    }
    my %scalars = ();
    for my $impl (@impls) {
        next unless(defined($impls{$impl}));
        my %vars = %{$impls{$impl}};
        for my $var (keys %vars) {
            $scalars{$impl."::".$var} = $vars{$var};
        }
    }
    my @files = ($schedule_file);
    for my $impl (@impls) {
        die "Don't know interface file for impl '$impl' while checking $schedule_file (".join(", ",@impls).")"
            unless(defined($impl_to_interface_ccl{$impl}));
        push @files, $impl_to_interface_ccl{$impl};
    }

    next unless(needs_update($macro_file,@files));

    print "Generating $macro_file\n";
    open($fd,">$macro_file") or die "could not open >$macro_file";
    print $fd "#ifndef macro_${thorn}_h\n";
    print $fd "#define macro_${thorn}_h\n";

    my %func_names=();

    for my $sched (@$scheds) {
        my $ngrp = findall("nogroup",$sched);
        next unless($#$ngrp == 0);
        my $func_name = $sched->{children}->[1]->{text};

        my @decls = @{findall("reads|writes",$sched)};
        my $line = $sched->{line};
        if(defined($func_names{$func_name})) {
            if($#decls >= 0 or $func_names{$func_name}->{count}>0) {
                warn "Warning: Function: $func_name is multiply defined in $schedule_ccl: lines $line and $func_names{$func_name}->{line}";
            }
        }
        $func_names{$func_name}->{line}=$line;
        $func_names{$func_name}->{count}=$#decls+1;

        print $fd "\n";
        print $fd contin("#define DECLARE_CCTK_ARGUMENTS_$func_name"),"\n";
        print $fd contin(" _DECLARE_CCTK_ARGUMENTS;"),"\n";
        print $fd contin(" cctk_func func_decl_(\"$func_name\");"),"\n";
        my %vars = ();
        for my $decl (@decls) {
            my $impl = undef;
            for my $qname (@{findall("qname",$decl)}) {
                my $root = $qname->{children}->[0]->{children};
                my $var_name;
                if(defined($root->[1])) {
                    $impl = $root->[0]->{text};
                    $var_name = $impl. "::" . $root->[1]->{text};
                } elsif(defined($impl)) {
                    $var_name = $impl . "::" . $root->[0]->{text};
                } else {
                    unlink($macro_file);
                    die "Undefined implementation for variable at $schedule_ccl:$qname->{line}";
                }
                if(defined($vars{$var_name})) {
                    if($decl->{name} eq "reads") {
                        if($vars{$var_name} eq "writes") {
                            $vars{$var_name} = "writereads";
                        }
                    } elsif($decl->{name} eq "writes") {
                        if($vars{$var_name} eq "reads") {
                            $vars{$var_name} = "readwrites";
                        }
                    }
                } else {
                    $vars{$var_name} = $decl->{name};
                }
            }
        }
        for my $var (keys %scalars) {
            $vars{$var} = "scalar";
        }
        my @vars = sort keys %vars;
        my $last_thorn = "";
        for(my $i=0;$i<=$#vars;$i++) {
            my $fullvar = $vars[$i];
            $fullvar =~ /(.*)::(.*)/ or die $fullvar;
            my $var = $2;
            my $thorn = uc($1);
            my $type = $vars{$fullvar};
            my $line = "";
            if($last_thorn ne $thorn) {
                print $fd contin(" cctk_auto_thorn = \"$thorn\";"),"\n";
                $last_thorn = $thorn;
            }
            if($type eq "scalar") {
                if($scalars{$fullvar} eq "int") {
                    $line = " DECLARE_CCTK_INT_SCALAR($var);";
                } elsif($scalars{$fullvar} eq "real") {
                    $line = " DECLARE_CCTK_REAL_SCALAR($var);";
                } elsif($scalars{$fullvar} eq "complex") {
                    $line = " DECLARE_CCTK_COMPLEX_SCALAR($var);";
                } else {
                    die "Not supported: scalar type = $scalars{$fullvar} for $fullvar";
                }
            } elsif($type eq "readwrites") {
                $line = " DECLARE_CCTK_READWRITES($var);";
            } elsif($type eq "writereads") {
                $line = " DECLARE_CCTK_WRITEREADS($var);";
            } elsif($type eq "writes") {
                $line = " DECLARE_CCTK_WRITES($var);";
            } elsif($type eq "reads") {
                $line =  " DECLARE_CCTK_READS($var);";
            } else {
                die "Unknown type: $type";
            }
            if($i < $#vars) {
                print $fd contin($line);
            } else {
                print $fd $line;
            }
            print $fd "\n";
        }
    }
    print $fd "#endif\n";
    close($fd);
}

sub contin {
    my $line = shift;
    while(length($line) < 60) {
        $line .= " ";
    }
    return $line."\\";
}
