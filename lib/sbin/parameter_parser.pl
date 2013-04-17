#! /usr/bin/perl -w
#/*@@
#  @file      parameter_parser.pl
#  @date      Mon 25 May 08:07:40 1998
#  @author    Tom Goodale
#  @desc
#  Parser for param.ccl files
#  @enddesc
#  @version $Header$
#@@*/
use Data::Dumper;
use Carp;
#use warnings;

#%implementations = ("flesh", "flesh", "test1", "test1", "test2", "test2");

#%parameter_database = create_parameter_database(%implementations);

sub incl {
    my $VAR;
    my $file = shift;
    local $/ = undef;
    my $fd = new FileHandle;
    unless(-r $file) {
        carp "File $file isn't readable";
    }
    open($fd,$file) or croak "Cannot open $file";
    my $c = <$fd>;
    close($fd);
    eval $c;
    return $VAR;
}

sub get_all {
    my $node = shift;
    my $tag = shift;
    
    if(!defined($node->{children})) {
    	return [];
    }
    
    my @ch = ();
    for my $ch (@{$node->{children}}) {
    	if($ch->{name} eq $tag) {
    		push @ch, $ch;
    	} else {
            push @ch, @{get_all($ch,$tag)};
        }
    }
    return \@ch;
}

sub dump_pair {
    my $array = shift;
    print "dump-pair=[\n";
    for(my $i=0;$i<=$#$array;$i+=2) {
        printf("%4d: {%s}{%s}\n",$i,$array->[$i],$array->[$i+1]);
    }
    print "]\n";
}

sub get_raw_text {
    my $parse_tree = shift;
    my $node = shift;
    my $input = undef;
    for my $ch (@{$parse_tree->{children}}) {
        if($ch->{name} eq "annot:src_txt") {
            $input = $ch->{text};
        }
    }
    my $txt = substr $input,$node->{start},$node->{end}-$node->{start};
    $txt =~ s/\\\s//g;
    return $txt;
}

sub get_raw {
    my $node = shift;
    my $txt = Dumper($node);
    $txt =~ s/\s+/ /g;
    return $txt;
}

sub get_text {
    my $node = shift;
    my $txt = "";
    if($node->{name} eq "quote") {
        $txt = $node->{text};
        $txt =~ s/^"//;
        $txt =~ s/"$//;
        $txt =~ s/\\\s//g;
    } elsif(defined($node->{text})) {
        $txt = $node->{text};
        $txt =~ s/\\\s//g;
    } else {
        for my $ch (@{$node->{children}}) {
            $txt .= get_text($ch);
        }
    }
    return $txt;
}

sub get_param_name {
    my $namenum = shift;
    croak unless($namenum->{name} eq "namenum");
    if($#{$namenum->{children}}==1) {
        return (
            $namenum->{children}->[0]->{text},
            $namenum->{children}->[1]->{text}
        );
    } else {
        return (
            $namenum->{children}->[0]->{text},
            undef
        );
    }
}

sub parse_par {
    my $parse_tree = shift;
    my $param_vec = shift;
    my $thorn = shift;
    my $type = shift;
    my $pars = get_all($parse_tree,"${type}par");
    for my $par (@{$pars}) {
        my $guts = undef;
        my ($uses,$extends) = (0,0);
        if($par->{children}->[0]->{name} eq "${type}guts") {
            $guts = $par->{children}->[0];
        } elsif($par->{children}->[1]->{name} eq "${type}guts") {
            if($par->{children}->[0]->{name} eq "uses") {
                $uses = 1;
            } else {
                $extends = 1;
            }
            $guts = $par->{children}->[1];
        } else {
            croak "No guts ".Dumper($par);
        }
        my @ranges = @{get_all($par,"${type}pair")};
        my ($param_name,$param_num) = get_param_name($guts->{children}->[0]);
        croak Dumper($guts) unless(defined($param_name));
        my $pre = uc("$thorn $param_name");
        my $desc = "";
        for(my $i=1;$i<=$#{$guts->{children}};$i++) {
            my $ch = $guts->{children}->[$i];
            if($ch->{name} eq "steerable") {
                push @$param_vec, "$pre steerable";
                push @$param_vec, $ch->{text};
            } elsif($ch->{name} eq "accname") {
                push @$param_vec, "$pre accumulator-base";
                push @$param_vec, $ch->{text};
            } elsif($ch->{name} eq "accumexpr") {
                push @$param_vec, "$pre accumulator-expression";
                push @$param_vec, get_raw_text($parse_tree,$ch);
            } elsif($ch->{name} eq "quote") {
                $desc = $guts->{children}->[1]->{text};
                $desc =~ s/\\\s//g;
            } elsif($ch->{name} eq "as") {
                my $as = $ch->{children}->[0]->{text};
                $pre = uc("$thorn $as");
            } else {
                carp "THORN=$thorn";
                carp Dumper($guts);
                croak Dumper($ch);
            }
        }
        if(defined($param_num)) {
            push @$param_vec, "$pre array_size";
            push @$param_vec, $param_num;
        }
        push @$param_vec, "$pre type";
        if($type eq "bool") {
            push @$param_vec, "BOOLEAN";
        } else {
            push @$param_vec, uc($type);
        }
        push @$param_vec, "$pre realname";
        push @$param_vec, $param_name;
        push @$param_vec, "$pre ranges";
        push @$param_vec, 1+$#ranges;
        push @$param_vec, "$pre description";
        push @$param_vec, $desc;
        croak $desc if($desc =~ /\\\s/);
        if($uses==0 and $extends==0) {
            push @$param_vec, "$pre default";
            my $last_child = $#{$par->{children}};
            my $default_val = get_text($par->{children}->[$last_child]);
            if($type eq "bool") {
                $default_val =~ s/^"(.*)"$/$1/;
            }
            push @$param_vec, $default_val;
        }
        for(my $i=0;$i<=$#ranges;$i++) {
            my $n = $i+1;
            push @$param_vec, "$pre range $n range";
            push @$param_vec, get_text($ranges[$i]->{children}->[0]);
            push @$param_vec, "$pre range $n description";
            push @$param_vec, get_raw_text($parse_tree,$ranges[$i]->{children}->[1]);
            #croak Dumper($ranges[$i]) if($pre eq "CARPET TIME_REFINEMENT_FACTORS" and $n == 2);
        }
    }
}

sub parse_param_ccl2 {
    my $thorn = shift;
    my $ccl_pm = $ENV{TOP}."/piraha/params/$thorn.pm";
    my $parse_tree = incl($ccl_pm);
    #print "parse_tree=",Dumper($parse_tree);
    my @param_vec = ();

    my $mode = "PRIVATE";
    my %mode = ("PRIVATE"=>"");
    my %shares = ();
    my $shares = undef;
    for my $ch (@{$parse_tree->{children}}) {
        if($ch->{name} eq "access") {
            $mode = $ch->{children}->[0]->{text};
            croak Dumper($ch) unless(defined($mode));
            $mode = uc($mode);
            if($thorn =~ /testsch/i and $mode =~ /RESTR/i) {
                print "GOT HERE: $thorn $mode\n";
            }
            if($#{$ch->{children}} == 1) {
                $shares = uc($ch->{children}->[1]->{text});
                $shares{$shares} = "";
                croak "[$mode]" unless($mode eq "SHARES");
            } else {
                if($mode eq "SHARES") {
                    $shares{$shares} = "";
                } else {
                    $shares = undef;
                    $mode{$mode} .= "";
                    if($thorn =~ /testsch/i and $mode =~ /RESTR/i) {
                        print "GOT HERE2: $thorn $mode\n";
                    }
                }
            }
        } elsif($ch->{name} =~ /^(string|keyword|real|int|bool)par$/) {
            my $pre = $1;
            my $guts = undef;
            if($ch->{children}->[0]->{name} eq $pre."guts") {
                $guts = $ch->{children}->[0];
            } elsif($ch->{children}->[1]->{name} eq $pre."guts") {
                $guts = $ch->{children}->[1];
            }
            my ($name,$num) = get_param_name($guts->{children}->[0]);
            if($#{$guts->{children}}>=1 and $guts->{children}->[1]->{name} eq "as") {
                $name = $guts->{children}->[1]->{children}->[0]->{text};
            }
            if(defined($shares)) {
                croak "Bad share" if($shares eq "");
                $shares{$shares} .= $name . " ";
            } else {
                $mode{$mode} .= $name . " ";
            }
        } elsif($ch->{name} =~ /annot:/) {
            ;
        } else {
            croak Dumper($ch);
        }
    }
    if($thorn =~ /testsch/i) {
        print "GOT HERE3: ",join(" ",keys %mode),"\n";
    }
    for my $m (keys %mode) {
        my $key = uc($thorn)." ".$m." variables";
        push @param_vec, $key;
        push @param_vec, $mode{$m};
    }

    push @param_vec, uc($thorn)." SHARES implementations";
    my @shares = keys %shares;
    push @param_vec, join(" ",sort @shares);
    for my $share (keys %shares) {
        my $impl = uc($share);
        push @param_vec, uc($thorn)." SHARES $impl variables";
        push @param_vec, $shares{$share};
    }

    &parse_par($parse_tree,\@param_vec,$thorn,"string");
    &parse_par($parse_tree,\@param_vec,$thorn,"int");
    &parse_par($parse_tree,\@param_vec,$thorn,"real");
    &parse_par($parse_tree,\@param_vec,$thorn,"keyword");
    &parse_par($parse_tree,\@param_vec,$thorn,"bool");
    return @param_vec;
}

sub scramble {
    my @args = @_;
    my $n = ($#args+1)/2;
    while($n > 0) {
        my $r = 2*int(rand($n));
        my @b=($r,$r+1,2*$n-2,2*$n-1);
        my $a = $args[$r];
        my $b = $args[$r+1];
        $args[  $r  ] = $args[2*$n-2];
        $args[  $r+1] = $args[2*$n-1];
        $args[2*$n-2] = $a;
        $args[2*$n-1] = $b;
        $n--;
    }
    return @args;
}

sub compare_pars {
    my $par1 = shift;
    my $par2 = shift;
    my %par1 = ();
    my %par2 = ();
    for(my $i=0;$i<=$#$par1;$i+=2) {
        my $k = $par1->[$i];
        my $v = $par1->[$i+1];
        croak $k unless($k =~ /^([A-Z0-9_]+ [A-Z0-9_\[\]]+) (.*)/);
        my ($k1,$k2)=($1,$2);
        $par1{$k1}->{$k2} = $v;
    }
    for(my $i=0;$i<=$#$par2;$i+=2) {
        my $k = $par2->[$i];
        my $v = $par2->[$i+1];
        croak $k unless($k =~ /^([A-Z0-9_]+ [A-Z0-9_\[\]]+) (.*)/);
        my ($k1,$k2)=($1,$2);
        $par2{$k1}->{$k2} = $v;
    }
    for my $k1 (keys %par1) {
        for my $k2 (keys %{$par1{$k1}}) {
            if(!defined($par2{$k1}->{$k2})) {
                $v = $par1{$k1}->{$k2};
                print "PAR ERROR: Missing key ($k1)($k2)=($v)\n";
            } else {
                my $v1 = $par1{$k1}->{$k2};
                my $v2 = $par2{$k1}->{$k2};
                $v1 =~ s/^[ \t]*"(.*)"[ \t]*$/$1/;
                $v2 =~ s/^[ \t]*"(.*)"[ \t]*$/$1/;
                if($v1 ne $v2) {
                    print "PAR ERROR: Noteq ($k1)($k2) => ($v1) ne ($v2)\n";
                }
            }
        }
    }
    for my $k1 (keys %par2) {
        for my $k2 (keys %{$par2{$k1}}) {
            if(!defined($par1{$k1}->{$k2})) {
                my $v = $par1{$k1}->{$k2};
                print "PAR ERROR: Extra key ($k1)($k2)=($v)\n";
            }
        }
    }
}

#/*@@
#  @routine    create_parameter_database
#  @date       Wed Sep 16 11:45:18 1998
#  @author     Tom Goodale
#  @desc
#  Creates a database of all the parameters
#  @enddesc
#@@*/

sub create_parameter_database
{
  my(%thorns) = @_;
  my($thorn, @indata);
  my(@new_parameter_data);
  my(@new_parameter_data2);
  my(@parameter_data);

  # Loop through each implementation's parameter file.
  foreach $thorn (sort keys %thorns)
  {
    print "   $thorn\n";
    #       Read the data
    @indata = &read_file("$thorns{$thorn}/param.ccl");

    # Get the parameters from it
    if($ENV{USE_PIRAHA} eq "False") {
        @new_parameter_data = &scramble(&parse_param_ccl($thorn, @indata));
    } else {
        @new_parameter_data2 = &scramble(&parse_param_ccl($thorn, @indata));
        @new_parameter_data = &parse_param_ccl2($thorn);

        &compare_pars(\@new_parameter_data,\@new_parameter_data2);
    }
    #print "parameter v1=";
    #&dump_pair(\@new_parameter_data);
    #print "parameter v2=";
    #&dump_pair(\@new_parameter_data2);

    &PrintParameterStatistics($thorn, @new_parameter_data);

    # Add the parameters to the master parameter database
    push (@parameter_data, @new_parameter_data);
  }

  @parameter_data = &cross_index_parameters(scalar(keys %thorns), (sort keys %thorns), @parameter_data);

  return @parameter_data;
}

sub cross_index_parameters
{
  my($n_thorns, @indata) = @_;
  my(@thorns);
  my(%parameter_database);
  my(@module_file);
  my($line);
  my(@data);
  my($thorn);

  @thorns = @indata[0..$n_thorns-1];
  %parameter_database = @indata[$n_thorns..$#indata];

  $parameter_database{"GLOBAL PARAMETERS"} = "";

  foreach $thorn (@thorns)
  {
    foreach $parameter (split(/ /, $parameter_database{"\U$thorn\E GLOBAL variables"}))
    {
      if($public_parameters{"\U$parameter\E"})
      {
        &CST_error(0, "Duplicate public parameter $parameter, defined in " .
                      "$thorn and " . $public_parameters{"\Uparameter\E"},
                   '', __LINE__, __FILE__);
      }
      else
      {
        $public_parameters{"\Uparameter\E"} = "$thorn";
        $parameter_database{"GLOBAL PARAMETERS"} .= "$thorn\::$parameter ";
      }
    }
  }

  return %parameter_database;
}



#/*@@
#  @routine    parse_param_ccl
#  @date       Wed Sep 16 11:55:33 1998
#  @author     Tom Goodale
#  @desc
#  Parses a param.ccl file and generates a database of the values.
#  @enddesc
#@@*/

sub parse_param_ccl
{
  my($thorn, @data) = @_;
  my($line_number, $line, $block, $type, $variable, $description);
  my($current_friend, $new_ranges, $new_desc);
  my($data, %parameter_db);
  my(%friends);
  my(%defined_parameters);
  my($use_or_extend, $use_clause, $skip_range_block);
  my($message);

  #   The default block is private.
  $block = 'PRIVATE';

  # Initialise, to prevent perl -w from complaining.
  $parameter_db{"\U$thorn PRIVATE\E variables"} = '';

  for($line_number = 0; $line_number < @data; $line_number++)
  {
    $line = $data[$line_number];

    # Parse the line
    if($line =~ m/(GLOBAL|RESTRICTED|PRIVATE|SHARES)\s*:\s*(\S*)\s*(.*)$/i)
    {
      # It's a new block.
      $block = "\U$1\E";

      if($block eq 'SHARES')
      {
        $current_friend = $2;
        $current_friend =~ s:\s::;

        if ($3 !~ /^\s*$/)
        {
          &CST_error(0, "More than one implementation on SHARES line in " .
                        "param.ccl for thorn $thorn",
                     '', __LINE__, __FILE__);
        }

        # It's a friend block.
        $block .= " \U$current_friend\E";
        # Remember this friend, but make the memory unique.
        $friends{"\U$current_friend\E"} = 1;
      }

      # Do some initialisation to prevent perl -w from complaining.
      $parameter_db{"\U$thorn $block\E variables"} = ''
        if(! $parameter_db{"\U$thorn $block\E variables"});
    }
    elsif($line =~ m/^\s*(EXTENDS\s+|USES\s+)?(?:CCTK_)?(INT|REAL|BOOLEAN|KEYWORD|STRING)\s+([a-zA-Z][a-zA-Z0-9_]*)(\s*\[([^]]+)\])?(\s+\"[^\"]*\")?\s*(.*)$/i)
    {
      # This is a parameter definition.

      my $use_or_extend = $1;
      my $type = "\U$2\E";
      my $variable = $3;
      my $array_size = $5;
      my $description = $6;
      my $options = $7;

      $description =~ s:^\s*::;

      $use_clause = ($use_or_extend =~ m:USES:i) ? 1 : 0;

      if($description !~ m:\":)
      {
        if($use_or_extend)
        {
          $description = '';
        }
        else
        {
          &CST_error(0, "Missing description for parameter $variable in " .
                        "param.ccl for thorn $thorn.",
                     "The first line of each parameter definition must have " .
                        "the syntax <TYPE> <NAME> <\"DESCRIPTION\">",
                     __LINE__, __FILE__);
        }
      }

      my $realname = $variable;

      # First deal with an alias
      if($options =~ m/\bAS\s+([^\s]+)\s*/i)
      {
        my $alias = $1;

        if($alias !~ m/[a-zA-Z]+[a-zA-Z0-9_]*/)
        {
          &CST_error(0, "Invalid alias name '$alias' for $variable of thorn " .
                     $thorn, '',__LINE__, __FILE__);
        }
        elsif($defined_parameters{"\U$alias\E"})
        {
          &CST_error(0, "Invalid alias name '$alias' for $variable of thorn " .
                     "$thorn - parameter of that name already exists",
                     '', __LINE__, __FILE__);
        }

        $options =~ s/\bAS\s+([^\s])+\s*//i;

        # Rename the variable for internal use
        $variable = $alias
      }

      if($defined_parameters{"\U$variable\E"})
      {
        &CST_error(1, "Duplicate parameter $variable in thorn $thorn. " .
                   "Ignoring second definition", '', __LINE__, __FILE__);
        $line_number++ until ($line_number>@data || $data[$line_number] =~ m:\}:);
      }
      elsif($use_or_extend && $use_or_extend =~ m:(EXTENDS|USES):i && $block !~ m:SHARES\s*\S:)
      {
        # Can only extend a friend variable.
        &CST_error(0, "Parse error in $thorn/param.ccl", '', __LINE__,__FILE__);
        $line_number++ until ($data[$line_number] =~ m:\}:);
      }
      elsif($data[$line_number+1] !~ m:^\s*\{\s*$: && $use_clause == 0)
      {
        # Since the data should have no blank lines, the next
        # line should have { on it.
        &CST_error(0, "Parse error in $thorn/param.ccl - missing \"{\" in " .
                      "definition of parameter '$variable'",
                   '', __LINE__, __FILE__);
        # Move past the end of this block.
        $line_number++ until ($data[$line_number] =~ m:\}:);
      }
      else
      {
        $skip_range_block = 0;
        # Move past {
        if($data[$line_number+1] !~ m:\s*\{\s*:)
        {
          if ($use_clause)
          {
            $skip_range_block = 1;
          }
          else
          {
#           This message is already given above.
#           &CST_error(0, "Missing { at start of range block for parameter " .
#                       "$variable pf thorn $thorn", '', __LINE__, __FILE__);
            die 'Internal error in parser: this line should never be reached.';
          }
        }
        else
        {
          $skip_range_block = 0;
          $line_number++;
          $line_number++;
        }

        # Parse the options
        %options = split(/\s*=\s*|\s+/, $options);

        foreach $option (sort keys %options)
        {
          if($option =~ m:STEERABLE:i)
          {
            $parameter_db{"\U$thorn $variable\E steerable"} = $options{$option};
          }
          elsif($option =~ m:ACCUMULATOR-BASE:i)
          {
            if($options{$option} =~ m/[a-zA-Z]+[a-zA-Z0-9_]*::([a-zA-Z]+[a-zA-Z0-9_]*)/)
            {
              if($defined_parameters{"\U$1\E"})
              {
                $parameter_db{"\U$thorn $variable\E accumulator-base"} = $options{$option};
              }
              else
              {
                &CST_error(0, "Unknown parameter '$options{$option}' " .
                              "specified as accumulator-base of $variable of " .
                              "thorn $thorn",
                           'if it comes from another thorn it must be shared',
                           __LINE__, __FILE__);
              }
            }
            elsif($options{$option} =~ m/[a-zA-Z]+[a-zA-Z0-9_]*/)
            {
              $parameter_db{"\U$thorn $variable\E accumulator-base"} = "$thorn\::$options{$option}";
            }
            else
            {
              &CST_error(0, "Invalid accumulator-base $options{$option} for " .
                            "$variable of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
          }
          elsif($option =~ m:ACCUMULATOR:i)
          {
            my $retcode = &CheckExpression($options{$option});

            if($retcode == 0)
            {
              $parameter_db{"\U$thorn $variable\E accumulator-expression"} = $options{$option};
            }
            elsif($retcode == 1)
            {
              &CST_error(0, "Invalid accumulator expression " .
                            "'$options{$option}' for $variable of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
            elsif($retcode == 2)
            {
              &CST_error(0, "Arithmetic error in accumulator expression " .
                            "'$options{$option}' for $variable of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
            elsif($retcode == 3)
            {
              &CST_error(0, "Accumulator expression '$options{$option}' " .
                            "can be infinite for $variable of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
            elsif($retcode == 4)
            {
              &CST_error(0, "Accumulator expression '$options{$option}' " .
                            "does not commute for $variable of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
            else
            {
              &CST_error(0, "Internal-error while checking accumulator " .
                            "expression '$options{$option}' for $variable " .
                            "of thorn $thorn",
                         '', __LINE__, __FILE__);
            }
          }
          else
          {
            &CST_error(0, "Unknown option '$option' for parameter $variable " .
                          "of thorn $thorn",
                       '', __LINE__, __FILE__);
          }
        }

        # Check array size
        if($array_size)
        {
          if($array_size !~ /^\d+$/)
          {
            &CST_error(0, "Invalid array size '$array_size' for parameter " .
                          "$variable of thorn $thorn",
                       '', __LINE__, __FILE__);
          }
          else
          {
            $parameter_db{"\U$thorn $variable\E array_size"} = $array_size;
          }
        }

        # Store data about this variable.
        $defined_parameters{"\U$variable\E"} = 1;
        $parameter_db{"\U$thorn $variable\E realname"} = $realname;
        $parameter_db{"\U$thorn $block\E variables"} .= $variable." ";
        $parameter_db{"\U$thorn $variable\E type"} = $type;
        $parameter_db{"\U$thorn $variable\E description"} = $description;
        $parameter_db{"\U$thorn $variable\E ranges"} = 0;

        if(! $skip_range_block)
        {
          # Parse the allowed values and their descriptions.
          # The (optional) description is seperated by ::
          while($data[$line_number] !~ m:^\s*\}:)
          {
            if($data[$line_number] =~ m/::/)
            {
              ($new_ranges, $delim, $new_desc) = $data[$line_number] =~ m/(.+?)(::)(.*)/;
            }
            else
            {
              ($new_ranges, $delim, $new_desc) = ($data[$line_number],"","");
            }
            # Increment the number of ranges found (ranges)
            $parameter_db{"\U$thorn $variable\E ranges"}++;

            # Strip out any leading and trailing spaces in the range
            $new_ranges =~ s/^\s*//;
            $new_ranges =~ s/\s*$//;
            # Strip out double quotes enclosing a non-numeric parameter range
            $new_ranges =~ s/^"(.*)"$/$1/ if ($type !~ m:INT|REAL:);

            # check integer parameter ranges
            if ($type eq 'INT' && ! (
                $new_ranges eq '*' ||
                $new_ranges =~ /^[+-]?\d+$/ ||
                $new_ranges =~ /^(\*|\(?[+-]?\d+)?:(\*|[+-]?\d+\)?)?(:\d+)?$/)) {
              &CST_error(0, "Invalid range '$new_ranges' for integer " .
                         "parameter '$variable' of thorn '$thorn'",
                         '', __LINE__, __FILE__);
            }

            $parameter_db{"\U$thorn $variable\E range $parameter_db{\"\U$thorn $variable\E ranges\"} range"} = $new_ranges;

            # Check description
            if($delim eq "" || ($delim =~ /::/ && $new_desc =~ /^\s*$/))
            {
              $new_ranges =~ /^\s*(.*)\s*\n/;
              &CST_error(1, "Missing description for range $1 for parameter " .
                            "$variable in param.ccl for thorn $thorn.",
                         "Each parameter range line should have the syntax " .
                            "<RANGE> :: <\"DESCRIPTION\">",
                         __LINE__, __FILE__);
            }
            elsif ($new_desc =~ /^\s*\".*[^\s\"]\s*$|^\s*[^\s\"].*\"\s*$/)
            {
              &CST_error(0, "Description of range for parameter $variable " .
                            "has misplaced quotes ($new_desc) in param.ccl " .
                            "for thorn $thorn",
                         '', __LINE__, __FILE__);
            }
            $parameter_db{"\U$thorn $variable\E range $parameter_db{\"\U$thorn $variable\E ranges\"} description"} = $new_desc;
            $line_number++;
          }
        }

        # Give a warning if no range was given and it was needed
        if (($use_clause == 0)  && ($parameter_db{"\U$thorn $variable\E ranges"}==0 && $type =~ m:INT|REAL:))
        {
          &CST_error(0, "No range provided for parameter $variable in " .
                        "param.ccl for thorn $thorn",
                     "All definitions for integer and real parameters must " .
                        "provide one or more allowed ranges",
                     __LINE__, __FILE__);
        }
        if($block !~ m:SHARES:)
        {
          if($data[$line_number] =~ m:\s*\}\s*([^\s].*)\s*:)
          {
            $default = $1;
            $default =~ m:^(.*[^\s])\s*:;
            $default = $1;

            if ($type eq 'INT' && $default !~ /^[+-]?\d+$/) {
              &CST_error(0, "Default '$default' for integer parameter " .
                         "'$variable' in thorn '$thorn' is not an integer",
                         '', __LINE__, __FILE__);
            }
            if ($type eq 'REAL' && $default !~ /^[+-]?(\d+([.]\d*)?|[.]\d+)([eEdD][+-]?\d+)?$/) {
              &CST_error(0, "Default '$default' for real parameter " .
                         "'$variable' in thorn '$thorn' is not a real",
                         '', __LINE__, __FILE__);
            }
            if ($type =~ m:INT|REAL: && $default =~ m:":)
            {
              &CST_error(0, "String default given for $type $variable in " .
                            "$thorn",
                         '', __LINE__, __FILE__);
            }
            elsif ($type =~ m:STRING: && $default !~ m:".*":)
            {
              &CST_error(0, "Default given for $type $variable in $thorn " .
                            "is not a string",
                         '', __LINE__, __FILE__);
            }
            elsif ($type =~ m:BOOLEAN: && $default =~ m:": && $default !~ m:".*":)
            {
              &CST_error(0, "Default given for $type $variable in $thorn " .
                            "is missing a quote",
                         '', __LINE__, __FILE__);
            }

            $default = $1 if ($default =~ m:\"(((\\\")|[^\"])*)\":);

            &CheckParameterDefault($thorn,$variable,$default,%parameter_db);

            $parameter_db{"\U$thorn $variable\E default"} = $default;
          }
          else
          {
            &CST_error(0, "Unable to find default value for parameter " .
                          "$variable",
                       "Last line of parameter block should be " .
                          "} <default value>",
                       __LINE__, __FILE__);
          }
        }
        if($block =~ m:SHARES:i)
        {
          if($data[$line_number] =~ m:\s*\}\s*([^\s].*)\s*:)
          {
            &CST_error(0, "param.ccl of thorn '$thorn' attempts to change " .
                          "default value of shared or extended parameter " .
                          "'$variable'",
                       '', __LINE__, __FILE__);
          }
        }
      }
    }
    else
    {
      if($line =~ m:\{:)
      {
        &CST_error(1, "Skipping parameter block in $thorn with missing keyword",
                   '', __LINE__, __FILE__);
        $line_number++ until ($data[$line_number] =~ m:\}:);
      }
      else
      {
        $line =~ /^(.*)\n*$/;
        &CST_error(0, "Unknown line in param.ccl for thorn $thorn\n\"$1\"",
                   '', __LINE__, __FILE__);
      }
    }
  }

  $parameter_db{"\U$thorn\E SHARES implementations"} = join(" ", sort keys %friends);

  return %parameter_db;
}

#/*@@
#  @routine    PrintParameterStatistics
#  @date       Sun Sep 19 13:04:18 1999
#  @author     Tom Goodale
#  @desc
#  Prints out some statistics about a thorn's param.ccl
#  @enddesc
#@@*/
sub PrintParameterStatistics
{
  my($thorn, %parameter_database) = @_;
  my($block);
  my($sep);

  if($parameter_database{"\U$thorn SHARES implementations"} ne "")
  {
    print "           Shares: " . $parameter_database{"\U$thorn SHARES implementations"} . "\n";
  }

  $sep = "          ";
  foreach $block ("Global", "Restricted", "Private")
  {
    print $sep . scalar(split(" ", $parameter_database{"\U$thorn $block\E variables"})) . " $block";
    $sep = ", ";
  }

  print " parameters\n";
}


#/*@@
#  @routine    CheckParameterDefault
#  @date       Sun Dec 17 18.20
#  @author     Gabrielle Allen
#  @desc
#  Check default in allowed range
#  @enddesc
#@@*/

sub CheckParameterDefault
{
  my($thorn,$variable,$default,%parameter_db) = @_;
  my($foundit,$i,$range);

  $foundit = 0;

  # Check that boolean default is correct
  if ($parameter_db{"\U$thorn $variable\E type"} =~ /BOOLEAN/)
  {
    if ($default !~ m:^yes|no|y|n|1|0|t|f|true|false$:i)
    {
      &CST_error(0, "Default ($default) for boolean parameter '$variable' " .
                    "is incorrect in param.ccl for thorn $thorn",
                 "The default value for a boolean parameter must be one of " .
                    "yes,no,y,n,1,0,t,f,true,false",
                 __LINE__, __FILE__);
    }
  }
  elsif ($parameter_db{"\U$thorn $variable\E type"} =~ /KEYWORD/)
  {
    $nranges=$parameter_db{"\U$thorn $variable\E ranges"};
    for ($i=1; $i<=$nranges; $i++)
    {
      # Keywords don't use pattern matching but are case insensitive
      $range = $parameter_db{"\U$thorn $variable\E range $i range"};
      $foundit = 1 if ("\U$default\E" eq "\U$range\E");
    }
    if ($foundit == 0)
    {
      &CST_error(0, "Default ($default) for keyword parameter '$variable' " .
                    "is incorrect in param.ccl for thorn $thorn",
                 "The default value for a parameter must lie within the " .
                    "allowed range",
                 __LINE__, __FILE__);
    }
  }
  elsif ($parameter_db{"\U$thorn $variable\E type"} =~ /STRING/)
  {
    $nranges=$parameter_db{"\U$thorn $variable\E ranges"};
    for ($i=1; $i<=$nranges; $i++)
    {
      $range = $parameter_db{"\U$thorn $variable\E range $i range"};

      # An empty regular expression should match everything.
      # Instead, perl returns the result of the last match.
      # Therefore, prevent using empty patterns.
      $foundit = 1 if ($range eq '' || $default =~ m:$range:i);
    }
    if ($foundit == 0)
    {
      &CST_error(0, "Default ($default) for string parameter '$variable' " .
                    "is incorrect in param.ccl for thorn $thorn",
                 "The default value for a parameter must lie within an " .
                    "allowed range",
                 __LINE__, __FILE__);
    }
  }
  elsif ($parameter_db{"\U$thorn $variable\E type"} =~ /INT/)
  {
    $nranges=$parameter_db{"\U$thorn $variable\E ranges"};
    for ($i=1; $i<=$nranges; $i++)
    {
      $range = $parameter_db{"\U$thorn $variable\E range $i range"};
      $range =~ /^([\(]?)([\s\*0-9]*):([\s\*0-9]*)([\)]?)/;
      $lower_bounds_excluded = $1 eq '(';
      $min = $2;
      $max = $3;
      $upper_bounds_excluded = $4 eq ')';
      $foundit = 1 if ($min =~ /^\s*[\*\s]*\s*$/ or
                       ($lower_bounds_excluded ? $default >  $min :
                                                 $default >= $min))
                      and
                      ($max =~ /^\s*[\*\s]*\s*$/ or
                       ($upper_bounds_excluded ? $default <  $max :
                                                 $default <= $max));
    }
    if ($nranges > 0 && $foundit == 0)
    {
      &CST_error(0, "Default ($default) for integer parameter '$variable' " .
                    "is incorrect in param.ccl for thorn $thorn",
                 "The default value for a parameter must lie within the " .
                    "allowed range",
                 __LINE__, __FILE__);
    }
  }
  elsif ($parameter_db{"\U$thorn $variable\E type"} =~ /REAL/)
  {
    $nranges=$parameter_db{"\U$thorn $variable\E ranges"};
    for ($i=1; $i<=$nranges; $i++)
    {
      $range = $parameter_db{"\U$thorn $variable\E range $i range"};
      $range =~ /^([\(]?)([\s\*0-9\.eE+-]*):([\s\*0-9\.eE+-]*)([\)]?)/;
      $lower_bounds_excluded = $1 eq '(';
      $min = $2;
      $max = $3;
      $upper_bounds_excluded = $4 eq ')';
      $foundit = 1 if ($min =~ /^\s*[\*\s]*\s*$/ or
                       ($lower_bounds_excluded ? $default >  $min :
                                                 $default >= $min))
                      and
                      ($max =~ /^\s*[\*\s]*\s*$/ or
                       ($upper_bounds_excluded ? $default <  $max :
                                                 $default <= $max));
    }
    if ($nranges > 0 && $foundit == 0)
    {
      &CST_error(0, "Default ($default) for real parameter '$variable' " .
                    "is incorrect in param.ccl for thorn $thorn",
                 "The default value for a parameter must lie within the " .
                    "allowed range",
                 __LINE__, __FILE__);
    }
  }
}

#/*@@
#  @routine    CheckExpression
#  @date       Fri May 17 21:26:52 2002
#  @author     Tom Goodale
#  @desc
#  Checks that an accumulator parameter's expression is valid.
#  The expression should commute when applied twice
#  I.e. if a is the original value of the parameter,
#          b the first value to add
#          c the second parameter to add
#      and L(x,y) the operation
#  The expression
#      L(L(a,b),c) = L(L(a,c),b)
#  should be true.
#  @enddesc
#
#  @var     expression
#  @vdesc   The expression to verify
#  @vtype   string
#  @vio     in
#  @endvar
#
#  @returntype int
#  @returndesc
#  0 -- success
#  1 -- expression contains invalid characters
#  2 -- expression could not be evaluated
#  3 -- expression can produce infinite result
#  4 -- expression does not commute
#  @endreturndesc
#@@*/
sub CheckExpression
{
  my ($expression) = @_;
  my $retcode;

  if($expression =~ m,^[-\d/*()+xy^!<>=]+$, &&
     $expression =~ m/\bx\b/            &&
     $expression =~ m/\by\b/            &&
     $expression !~ m/\wx/              &&
     $expression !~ m/x\w/              &&
     $expression !~ m/\wy/              &&
     $expression !~ m/y\w/)
  {

    # Pick some numbers to do the test with.
    my $a = 37;
    my $b = 53;
    my $c = 59;

    # Convert to Perl's exponentiation operator syntax.
    $expression =~ s/\^/**/;

    # Convert x and y to Perl variables.
    $expression =~ s/x/\$x/g;
    $expression =~ s/y/\$y/g;

    # Calculate L(L(a,b),c).
    my $answer1 = &EvalExpression(&EvalExpression($a,$b,"$expression"),$c,$expression);

#    print "$answer1\n" if defined $answer1;

    # Calculate L(L(a,c),b).
    my $answer2 = &EvalExpression(&EvalExpression($a,$c,"$expression"),$b,$expression);

#    print "$answer2\n" if defined $answer2;

    if( !defined $answer1 || ! defined $answer2)
    {
      $retval = 2;
    }
    elsif($answer1 eq "inf" || $answer2 eq "inf")
    {
      $retval = 3;
    }
    elsif(abs($answer1 - $answer2) > 1.0e-17)
    {
      $retval = 4;
    }
    else # if($answer1 == $answer2)
    {
      $retval = 0;
    }
  }
  else
  {
    $retval = 1;
  }

  return $retval;
}


#/*@@
#  @routine    EvalExpression
#  @date       Fri May 17 21:34:18 2002
#  @author     Tom Goodale
#  @desc
#  Takes an expression involving $x and $y
#  and evaluates it.
#  @enddesc
#
#  @var     x
#  @vdesc   An argument in the expression
#  @vtype   scalar
#  @vio     in
#  @endvar
#  @var     y
#  @vdesc   An argument in the expression
#  @vtype   scalar
#  @vio     in
#  @endvar
#  @var     expression
#  @vdesc   The expression to evaluate
#  @vtype   string
#  @vio     in
#  @endvar
#
#  @returntype scalar
#  @returndesc
#    The value of the evaluation.
#  @endreturndesc
#@@*/
sub EvalExpression
{
  my ($x, $y, $expression) = @_;

  my $answer = eval "$expression";

  return $answer;
}


1;
