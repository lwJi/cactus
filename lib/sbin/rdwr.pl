use lib ".";
use Piraha;
use FileHandle;
use Carp;
use Data::Dumper;
use strict;

my $sch_file = $ENV{CCTK_HOME}."/src/piraha/pegs/schedule.peg";
my($S_grammar,$S_rule)=piraha::parse_peg_file($sch_file);

my $int_file = $ENV{CCTK_HOME}."/src/piraha/pegs/interface.peg";
my($I_grammar,$I_rule)=piraha::parse_peg_file($int_file);

#############################################################################
#
#                      Subroutines
#
#############################################################################


#/*@@
#  @routine get_cap
#  @date    Tue 17 Mar 2020 10:12:37 PM UTC
#  @author  Steven R. Brandt
#  @desc
#           Look up correct capitalization (interface.ccl file)
#           so that READ/WRITE declarations don't need to worry
#           about case.
#  @enddesc
#@@*/
sub get_cap {
    my $hash = shift;
    my $th = shift;
    my $var = shift;
    my $realvar = $var;;
    my $suffix = "";
    if($var =~ /(.*?)((_p)*)$/) {
        $realvar = $1;
        $suffix = $2;
    }
    my $outvar;
    if(defined($hash->{private_variable}->{$th}->{capitalization}->{$realvar})) {
        $outvar = $hash->{private_variable}->{$th}->{capitalization}->{$realvar} . $suffix;
    } elsif(defined($hash->{$th}->{capitalization}->{$realvar})) {
        $outvar = $hash->{$th}->{capitalization}->{$realvar} . $suffix;
    } else {
        croak("No Capitalization for ($realvar)");
    }
    return $outvar;
}

#/*@@
#  @routine thorn_args
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt
#  @desc
#           Parses previously generated
#           Fortran headers to determine
#           the list of grid functions passed
#           to Fortran function calls within
#           a thorn.
#  @enddesc
#@@*/

sub thorn_args {
    my $th = shift;
    my $TOP = $ENV{TOP};
    my $fname="$TOP/bindings/include"; #${th}_Arguments.h";
    my $found = 0;
    for my $f (<*_Arguments.h>) {
        if(uc($f) eq "${th}_ARGUMENTS.H") {
            $fname .= "/$f";
            $found = 1;
            last;
        }
    }
    if(!$found) {
        print("Not found: thorn '$th'\n");
        return [];
    }
    my $fd = new FileHandle;
    my $find = "#define \U${th}\E_(PRIVATE|PUBLIC|PROTECTED)_FARGUMENTS ";
    unless(open($fd,$fname)) {
        print("No such file: '$fname'\n");
        return [];
    }
    my @vars = ();
    while(my $line=<$fd>) {
        if($line =~ /$find/) {
            $line=<$fd>;
            while($line =~ /\w+/g) {
                push @vars, lc $&;
            }
        }
    }
    return \@vars
}

#/*@@
#  @routine interface_starter
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           Walk through the Piraha parse tree
#           and process all implementations.
#  @enddesc
#@@*/

sub interface_starter
{
  my $thornname = uc shift;
  my $hash = shift;
  my $gr = shift;
  my $ccl_file = shift;
  for my $ch (@{$gr->{children}}) {
    if($ch->is("FUNC_GROUP")) {
      for my $gch (@{$ch->{children}}) {
        if($gch->is("IMPLEMENTS")) {
          # This finds the implementation name for the thorn.
          my $name = uc $gch->has(0,"name")->substring();
          $hash->{$name} = {} if(!defined($hash->{$name}));
          do_interfaces($hash->{$name},$gr,$ccl_file);
          # Private variables are referenced by thorn name instead
          # of implementation name. The 'private' key stores the
          # variables under the thorn name to handle this.
          $hash->{private_variable}->{$thornname} = $hash->{$name};
          return;
        }
      }
    }
  }
}

#/*@@
#  @routine do_interfaces
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           Walk through the Piraha parse tree
#           and process all items under the
#           GROUP_VARS rule.
#  @enddesc
#@@*/

sub do_interfaces
{
  my $hash = shift;
  my $gr = shift;
  my $ccl_file = shift;
  if($gr->is("GROUP_VARS")) {
    my $vtype = $gr->has(0,"vtype")->substring();
    my $level = 0;
    my $vecval = "0";
    my $dim = 0;
    my $gname;
    my $gtype;
    my $cap_gname;
    for my $ch (@{$gr->{children}}) {
      if($ch->is("gname")) {
        $cap_gname = $ch->has(0,"name")->substring();
        $gname = lc $cap_gname;
        if($ch->has(1,"expr")) {
          # This section finds the length for vectors.
          my $expr = $ch->has(1,"expr")->has(0,"addexpr")->has(0,"mulexpr")->has(0,"powexpr");
          if($expr->has(0,"num")) {
            $vecval = $expr->has(0,"num")->substring();
          } elsif($expr->has(0,"accname")) {
            $vecval = $expr->has(0,"accname")->substring();
          } elsif($expr->has(0,"parexpr")) {
            $vecval = $expr->has(0,"parexpr")->substring();
          } else {
            my $loc = "(".$ccl_file."::".$expr->linenum().")";
            &CST_error(0, "Unexpected structure encountered in interface parsing at $loc"
                , "", __LINE__, __FILE__);
          }
        }
      } elsif($ch->is("gtype")) {
        $gtype = $ch->substring();
      } elsif($ch->is("dim") and (uc $gtype) eq "ARRAY") {
        $dim = $ch->substring();
      } elsif($ch->is("timelevels")) {
        $level = $ch->substring();
        last;
      }
    }
    if($level-1 < 0) {
      $hash->{$gname}->{level} = 0;
    } else {
      $hash->{$gname}->{level} = $level-1;
    }
    $hash->{$gname}->{vtype} = uc $vtype;
    $hash->{$gname}->{vector} = $vecval;
    $hash->{$gname}->{gtype} = uc $gtype;
    $hash->{$gname}->{array_dim} = $dim;
    $hash->{group_list}->{$gname}=1;
    $hash->{capitalization}->{$gname}=$cap_gname;
    my $Detect = 0;
    for my $ch (@{$gr->{children}}) {
      # Looping over variables in the group
      if($ch->is("VARS")) {
        my $i = 0;
        $Detect = 1;
        while($ch->has($i,"name")) {
          my $cap_var = $ch->has($i,"name")->substring();
          my $var = lc $cap_var;
          $hash->{$gname}->{grp_vars}->{$var} = $var;
          $hash->{variable_list}->{$var} = $gname;
          $hash->{capitalization}->{$var} = $cap_var;
          $i++;
        }
        last;
      }
    }
    if($Detect == 0) {
      # If no VARS were detected, then the group name
      # is also the variable name.
      $hash->{$gname}->{grp_vars}->{$gname} = $gname;
      $hash->{variable_list}->{$gname} = $gname;
      $hash->{capitalization}->{$gname} = $cap_gname;
    }
  } elsif($gr->{name} =~ /^(intr|FUNC_GROUP)$/) {
    # 'intr' is the name of the top-level pattern for an entire interface file
    for my $ch (@{$gr->{children}}) {
      do_interfaces($hash,$ch,$ccl_file);
    }
  }
}

#/*@@
#  @routine schedule_starter
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           Declare some variables, then
#           call do_schedules to parse the
#           schedule tree, and create_macros
#           to generate the per-function
#           macro definitions.
#  @enddesc
#@@*/

sub schedule_starter
{
  my $tnm = uc shift;
  my $hash = shift;
  my $gr = shift;
  my $ccl_file = shift;
  my $lang = {};
  my $reads_writes = {};
  my $data = "";
  do_schedules($gr,$reads_writes,$lang,$ccl_file);
  create_macros($tnm,$hash,$gr,$reads_writes,$lang,\$data,$ccl_file);
  return $data;
}

#/*@@
#  @routine do_schedule
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           Parse the schedule tree and look for
#           reads/writes/invalidates definitions.
#  @enddesc
#@@*/

sub do_schedules
{
  my $gr = shift;
  my $reads_writes = shift;
  my $lang = shift;
  my $ccl_file = shift;
  $ccl_file =~ m{([^/]+)/schedule.ccl$};
  my $parsing_thorn = $1;
  if($gr->is("schedule")) {
    next if($gr->has(0,"group")); #groups have no rd/wr clauses...
    my $nm;
    for my $ch (@{$gr->{children}}) {
      if($ch->is("name")) {
        $nm = $ch->substring();
      } elsif($ch->is("lang")) {
        # Cactus allows for functions to have the same name if
        # they are different languages. Because of this, the
        # different functions must be distinguished for macro
        # generation. '_C' or '_F' are appended to the end of
        # the function name for clarity.
        my $language = uc $ch->has(0,"name")->substring();
        $nm .= "_".substr($language,0,1);
        $lang->{$nm} = $language;
        last;
      }
    }
    for my $ch (@{$gr->{children}}) {
      if($ch->is("reads") or $ch->is("writes")) {
        my $is_writes = $ch->is("writes");
        
        # First we extract the thorn and variable name from the reads/writes clause
        my $qname = $ch->has(0,"qname");
        my $vname = $qname->has(0,"vname");
        my $thorn_or_var = $vname->has(0,"name")->substring();
        my $thorn = undef;
        my $var = undef;
        my $cap_thorn = undef;
        my $cap_var = undef;
        if($vname->has(1,"name")) {
            $cap_thorn = $thorn_or_var;
            $cap_var = $vname->has(1,"name")->substring();
            $thorn = uc $cap_thorn;
            $var = lc $cap_var;
        } else {
            $cap_thorn = $parsing_thorn;
            $cap_var = $thorn_or_var;
            $thorn = uc $cap_thorn;
            $var = lc $cap_var;
        }

        # update informational data structures
        $reads_writes->{$nm}->{$thorn}->{$var}->{rdwr} += $is_writes;
        $reads_writes->{$nm}->{$thorn}->{$var}->{line} = $vname->linenum();
        $reads_writes->{$nm}->{$thorn}->{$var}->{cap} = "${cap_thorn}::${cap_var}";
        my $i = 1;

        # we skip over the region, e.g. interior, boundary, etc.
        # as that doesn't play a part in the generation of the macros.
        $i++ if($qname->has($i,"region"));

        # Process additional variable names in this definition.
        while($qname->has($i,"qrname")) {
          my $qrname = $qname->group($i);
          $var = lc $qrname->has(0,"name")->substring();
          $reads_writes->{$nm}->{$thorn}->{$var}->{rdwr} += $is_writes;
          $reads_writes->{$nm}->{$thorn}->{$var}->{line} = $vname->linenum();
          $i++;
        }

        if(defined($reads_writes->{$nm}->{$nm}->{$nm})) {
            delete $reads_writes->{$nm}->{$nm}->{$nm};
        }
      }
    }
    if(!defined($reads_writes->{$nm})) {
      # In the event that a function has no declarations,
      # an empty macro still needs to be generated. This
      # handles that case. Since a function can be scheduled
      # multiple times, this hash key is deleted if later
      # scheduling adds variables to the list of read/write
      # declarations.
      $reads_writes->{$nm}->{$nm}->{$nm}->{rdwr} = "empty";
      $reads_writes->{$nm}->{$nm}->{$nm}->{line} = $gr->linenum();
    }
  } else {
    for my $ch (@{$gr->{children}}) {
      do_schedules($ch,$reads_writes,$lang);
    }
  }
}

#/*@@
#  @routine create_macros
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           Generate the function specific macros.
#  @enddesc
#@@*/

sub create_macros
{
  my $tnm = uc shift;
  my $hash = shift;
  my $gr = shift;
  my $reads_writes = shift;
  my $lang = shift;
  my $data = shift;
  my $ccl_file = shift;
  my $thorn_args = thorn_args($tnm);
  my $all_cctk_arguments = [];
  push @$all_cctk_arguments, @$thorn_args;
  $$data .= "#ifndef CCTK_ARGUMENTS_CHECKED_H\n";
  $$data .= "#define CCTK_ARGUMENTS_CHECKED_H 1\n";
  for my $namekey (sort keys %{$reads_writes}) {
    my %cctk_arguments = ();

    # Ensure the Fortran or C suffix is present
    croak($namekey) unless($namekey =~ /_(F|C)$/);

    my $nm = substr($namekey,0,-2); # removing language suffix from function name
    if(defined($reads_writes->{$namekey}->{$namekey}->{$namekey})) {
      # This generates macros for functions with no read/write declarations.
      if ($lang->{$namekey} eq "C") {
        $$data .= "#ifdef CCODE \n";
        $$data .= "#ifndef DECLARE_CCTK_ARGUMENTS_${nm} \n";
        $$data .= "#define DECLARE_CCTK_ARGUMENTS_${nm} \\\n";
        $$data .= "  _DECLARE_CCTK_ARGUMENTS; \\\n";
        $$data .= "  /* end $nm */\n";
        $$data .= "#endif\n";
        $$data .= "#endif\n";
      } elsif ($lang->{$namekey} eq "FORTRAN") {
        $$data .= "#ifdef FCODE \n";
        $$data .= "#ifndef DECLARE_CCTK_ARGUMENTS_${nm} \n";
        $$data .= "#define DECLARE_CCTK_ARGUMENTS_${nm} \\\n";
        $$data .= "  _DECLARE_CCTK_FARGUMENTS; \\\n";
        for my $var (@$all_cctk_arguments) {
          if(not defined($cctk_arguments{$var})) {
              # In Fortran, all GF's are passed in regardless of
              # whether a read or write declaration exists. Since
              # we cannot avoid declaring them, we declare them
              # as something useless that cannot automatically
              # be converted into an int or float. The unsual
              # capitalization makes it easier to identify in
              # generated files.
              $$data .= " characTer*8, intent(IN) :: $var /* dummy-rdwr-var */ && \\\n";
          }
        }
        $$data .= "  /* end $nm */\n";
        $$data .= "#endif\n";
        $$data .= "#endif\n";
      } else {
        my $loc = "(".$ccl_file."::".$lang->linenum().")";
        &CST_error(0, "Failed to match the language for the function $nm at $loc"
            ,"", __LINE__, __FILE__);
      }
    } else {
      if($lang->{$namekey} eq "C") {
        $$data .= "#ifdef CCODE \n";
        $$data .= "#ifndef DECLARE_CCTK_ARGUMENTS_${nm} \n";
        $$data .= "#define DECLARE_CCTK_ARGUMENTS_${nm} \\\n";
        $$data .= "  _DECLARE_CCTK_ARGUMENTS; \\\n";
        $$data .= "  CCTK_Checked_called(); \\\n";
        for my $th (sort keys %{$reads_writes->{$namekey}}) {
          for my $full_var (sort keys %{$reads_writes->{$namekey}->{$th}}) {
            my $errline = $reads_writes->{$namekey}->{$th}->{$full_var}->{line};
            my $var_group;
            my $group_register = "no";
            my $var = $full_var;
            my $timelevel = 0;
            while((substr $var,-2,2) eq "_p") {
              # This loop determines the timelevel by tallying the
              # timelevel suffixes '_p' and removing them from the
              # variable name.
              $var = substr $var,0,-2;
              $timelevel++;
            }
            if(defined($hash->{$th}->{variable_list}->{$var})) {
              # public variables
              my $group = $hash->{$th}->{variable_list}->{$var};
              $var_group = $hash->{$th}->{$group};
            } elsif(($tnm eq $th) && defined($hash->{private_variable}->{$th}->{variable_list}->{$var})) {
              # private variables
              my $group = $hash->{private_variable}->{$th}->{variable_list}->{$var};
              $var_group = $hash->{private_variable}->{$th}->{$group};
            } elsif(defined($hash->{$th}->{group_list}->{$var})) {
              # variable name is actually a group
              $var_group = $hash->{$th}->{$var};
              $group_register = "yes";
            } else {
              my $cap = $reads_writes->{$namekey}->{$th}->{$var}->{cap};
              my $hint = "Is $cap a correctly declared variable?";
              my %hints = ();
              # Do a brute force search of the world...
              for my $th2 (keys %$hash) {
                for my $v (%{$hash->{private_variable}->{$th2}->{variable_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
                for my $v (%{$hash->{$th2}->{variable_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
                for my $v (%{$hash->{$th2}->{group_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
              }
              my @hints = keys %hints;
              if($#hints >= 0) {
                $hint = join(" ",@hints);
              }
              # Regardless of whether we found a capitalization
              # match or not, we report an error.
              if(!defined($hint)) {
                $hint = "Check variable or group '${th}::$full_var' and verify ".
                    "correct implementation/thorn name and variable name.'";
              }
              &CST_error(1, "Error read/write declaration in $nm schedule."
                    ,$hint, , $errline, $ccl_file);
              next;
            }
            my $vtype = "CCTK_".$var_group->{vtype};
            # This next test only fails if we could not determine
            # the variable type...
            if($vtype eq "CCTK_") {
              my $hint = "Bad variable group name '$full_var' at $errline";
              &CST_error(1, "Error in read/write declaration $nm schedule. Check variable or group '$full_var'" .
                    ' and verify correct implementation/thorn name and variable name.'
                    ,$hint, , $errline, $ccl_file);
              next;
            }

            # Add const for read-only variables.
            my $const = "";
            $const = "const" if($reads_writes->{$namekey}->{$th}->{$full_var}->{rdwr}==0);

            # Write out the C++ declarations for the group or variable
            if($group_register eq "yes") {
              for my $variables (sort keys %{$var_group->{grp_vars}}) {
                my $var = $variables;
                for(my $tl=0;$tl<$timelevel;$tl++) {
                    $var .= "_p";
                }
                my $vname = "${th}::$variables";
                if ($var_group->{vector} ne "0") {
                  $vname .= "[0]";
                }
                my $ivar = get_cap($hash, $th, $var);
                $$data .= qq(static int cctki_vi_$ivar = -100; if (cctki_vi_$ivar == -100) cctki_vi_$ivar = CCTK_VarIndex("$vname"); $vtype * restrict const $ivar __attribute__((__unused__)) = (($vtype *) CCTKi_VarDataPtrI(cctkGH, $timelevel, cctki_vi_$ivar));; /* group $group_register */\\\n);
              }
            } else {
              my $ivar = get_cap($hash, $th, $full_var);
              my $vname = "${th}::$ivar";
              if ($var_group->{vector} ne "0") {
                $vname .= "[0]";
              }
              $$data .= qq(static int cctki_vi_$ivar = -100; if (cctki_vi_$ivar == -100) cctki_vi_$ivar = CCTK_VarIndex("$vname"); $vtype * restrict const $ivar __attribute__((__unused__)) = (($vtype *) CCTKi_VarDataPtrI(cctkGH, $timelevel, cctki_vi_$ivar));; /* TL: $namekey --> $timelevel $group_register*/\\\n);
            }
          } # loop over read/write variables
        } # loop over read/write thorns
      } elsif($lang->{$namekey} eq "FORTRAN") {
        my $vector_len = {};
        $$data .= "#ifdef FCODE \n";
        $$data .= "#ifndef DECLARE_CCTK_ARGUMENTS_${nm} \n";
        $$data .= "#define DECLARE_CCTK_ARGUMENTS_${nm} \\\n";
        $$data .= "  _DECLARE_CCTK_FARGUMENTS \\\n";
        for my $th (sort keys %{$reads_writes->{$namekey}}) {
          for my $full_var (sort keys %{$reads_writes->{$namekey}->{$th}}) {
            my $var_group;
            my $group;
            my $group_register;
            my $var = $full_var;
            my $timelevel = 0;
            while((substr $var,-2,2) eq "_p") {
              # This loop determines the timelevel by tallying the
              # timelevel suffixes '_p' and removing them from the
              # variable name.
              $var = substr $var,0,-2;
              $timelevel++;
            }
            if(defined($hash->{$th}->{variable_list}->{$var})) {
              # public variables
              $group = $hash->{$th}->{variable_list}->{$var};
              $var_group = $hash->{$th}->{$group};
            } elsif(($tnm eq $th) && defined($hash->{private_variable}->{$th}->{variable_list}->{$var})) {
              # private variables
              $group = $hash->{private_variable}->{$th}->{variable_list}->{$var};
              $var_group = $hash->{private_variable}->{$th}->{$group};
            } elsif(defined($hash->{$th}->{$var})) {
              # variable name is actually a group
              $group = $var;
              $var_group = $hash->{$th}->{$var};
              $group_register = "yes";
            } else {
              # So $var isn't a public variable, a private variable,
              # or a group name...
              #
              # Maybe it's a capitalization problem?
              #
              # We need the write directive in the schedule.ccl to
              # match the case of the corresponding declaration in
              # the interface.ccl. If it doesn't line up, an error
              # will occur. This helps the user figure it out.
              my $hint = undef;
              ###
              my $cap = $reads_writes->{$namekey}->{$th}->{$var}->{cap};
              my $hint = "Is $cap a correctly declared variable?";
              my %hints = ();
              # Do a brute force search of the world...
              for my $th2 (keys %$hash) {
                for my $v (%{$hash->{private_variable}->{$th2}->{variable_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
                for my $v (%{$hash->{$th2}->{variable_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
                for my $v (%{$hash->{$th2}->{group_list}}) {
                  if($v eq lc $var) {
                    $hints{" Did you mean ${th2}::$v?"}=1;
                  }
                }
              }
              my @hints = keys %hints;
              if($#hints >= 0) {
                $hint = join(" ",@hints);
              }
              ###
              &CST_error(0, "Error in $nm schedule. Check variable or group '${th}::$full_var'" .
                    ' and verify correct implementation/thorn name and variable name.'
                    ,$hint, , __LINE__, __FILE__);
            }
            my $vtype = "CCTK_".$var_group->{vtype};
            $vtype .= ", iNteNt(iN)" if($reads_writes->{$namekey}->{$th}->{$full_var}==0);
            my $arrays = "";
            # The following logic determines the correct
            # indexing for the Fortran arrays and adds the
            # index variables to the macro.
            if($var_group->{gtype} eq "GF") {
              if($var_group->{vector} ne "0") {
                my $glen = $group."_length";
                if(!defined($vector_len->{$glen})) {
                  $cctk_arguments{$glen}=1;
                  $$data .= "  integer :: $glen &&\\\n";
                  $vector_len->{$glen} = 1;
                }
                $arrays = qq((cctk_ash1,cctk_ash2,cctk_ash3,$glen));
              } else {
                $arrays = qq((cctk_ash1,cctk_ash2,cctk_ash3));
              }
            } elsif($var_group->{gtype} eq "ARRAY") {
              if($var_group->{vector} ne "0") {
                croak("Not supported yet.");
              }
              my $glen = "x0".$group;
              if(!defined($vector_len->{$glen})) {
                $cctk_arguments{$glen}=1;
                $$data .= "  integer :: $glen &&\\\n";
                $vector_len->{$glen} = 1;
              }
              for(my $i = 1; $i < $var_group->{array_dim}; $i++) {
                my $temp_glen .= "x".$i.$group;
                $glen .= ",".$temp_glen;
                if(!defined($vector_len->{$temp_glen})) {
                  $cctk_arguments{$temp_glen}=1;
                  $$data .= "  integer :: $temp_glen &&\\\n";
                  $vector_len->{$temp_glen} = 1;
                }
              }
              $arrays = qq(($glen));
            } elsif($var_group->{vector} ne "0") {
              my $glen = $group."_length";
              $cctk_arguments{$glen}=1;
              $$data .= "  integer :: $glen &&\\\n";
              $arrays = qq(($glen));
            }
            if($group_register eq "yes") {
              for my $variable (sort keys %{$var_group->{grp_vars}}) {
                $cctk_arguments{$variable}=1;
                $$data .= "  $vtype :: $variable $arrays &&\\\n";
                $$data .= "  integer, parameter :: cctki_use_$variable = kind($variable) &&\\\n";
              }
            } else {
              $cctk_arguments{$full_var}=1;
              $$data .= "  $vtype :: $full_var $arrays &&\\\n";
              $$data .= "  integer, parameter :: cctki_use_$full_var = kind($full_var) &&\\\n";
            }
          } # loop over read/write variables
        } # loop over read/write thorns
        # Declare the variables that got missed...
        for my $var (@$all_cctk_arguments) {
          if(not defined($cctk_arguments{$var})) {
              $$data .= " characTer*8, intent(IN) :: $var /* dummy-rdwr-var */ && \\\n";
          }
        }
      } else {
        &CST_error(0, "Failed to match the language for the function $nm."
            ,"", __LINE__, __FILE__);
      }
      $$data .= "  /* end $nm */\n";
      $$data .= "#endif\n";
      $$data .= "#endif\n";
    } # if logic for empty/non-empty macros
  } #loop over functions
  $$data .= "#endif";
}

#/*@@
#  @routine GenerateArguments
#  @date    Mon Feb 24 16:10:38 EST 2020
#  @author  Steven R. Brandt and Samuel D. Cupp
#  @desc
#           This is the entry point into the
#           rdwr macro generation logic. It
#           is also reponsible for calling
#           WriteFile.
#  @enddesc
#@@*/
#
sub GenerateArguments
{
  my %thorns = @_;
  my $hash = {};
  my $ccl_file;
  for my $key (keys %thorns) {
    $ccl_file = $thorns{$key}."/interface.ccl";
    my $gr=parse_ccl($I_grammar,$I_rule,$ccl_file,$int_file);
    if($gr) {
      interface_starter($key,$hash,$gr,$ccl_file);
    }
  }
  for my $key (keys %thorns) {
    $ccl_file = $thorns{$key}."/schedule.ccl";
    my $gr=parse_ccl($S_grammar,$S_rule,$ccl_file,$sch_file);
    if($gr) {
      my $data = "";
      $data .= "#ifdef CCODE\n";
      $data .= "extern\n";
      $data .= "#ifdef __cplusplus\n";
      $data .= "\"C\"\n";
      $data .= "#endif\n";
      $data .= "void CCTK_Checked_called();\n";
      $data .= "#endif\n";
      $data .= schedule_starter($key,$hash,$gr,$ccl_file);
      WriteFile($ENV{TOP}."/bindings/include/$key/cctk_Arguments_Checked.h", \$data);
    }
  }
}

1;
