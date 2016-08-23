#! /usr/bin/perl -w
use strict;

my $ccl_file = undef;

use Carp;
use FileHandle;
use Data::Dumper;

sub trim_quotes
{
  my $str = shift;
  $str =~ s/^(["'])(.*)\1$/$2/s;
  return $str;
}

# TODO: Still needed?
sub expr
{
  my $expr = shift;
  my $nm = $expr->{name};
  if($nm eq "expr" or $nm eq "addexpr" or $nm eq "mulexpr" or $nm eq "powexpr") {
    my $buf = "";
    for my $c (@{$expr->{children}}) {
      $buf .= expr($c);
    }
    return $buf;
  } elsif($nm eq "parexpr") {
    return "(".expr($expr->group(0)).")";
  } elsif($nm eq "negexpr") {
    return "-".expr($expr->group(0));
  } elsif($nm eq "addop" or $nm eq "mulop" or $nm eq "accname" or $nm eq "num") {
    return $expr->substring();
  }
  confess("EXPR: $nm");
}

#/*@@
#  @file    interface_parser.pl
#  @date    Wed Sep 16 15:07:11 1998
#  @author  Tom Goodale
#  @desc
#           Parses interface.ccl files
#  @enddesc
#  @version $Header$
#@@*/

#/*@@
#  @routine    create_interface_database
#  @date       Wed Sep 16 15:07:11 1998
#  @author     Tom Goodale
#  @desc
#  Creates a database of all the interfaces
#  @enddesc
#@@*/

sub create_interface_database
{
  my $interface_data = shift;
  my($n_system,@inargs) = @_;
  my(%system_database);
  my(%thorns, @thorns);
  die "BAD HASH" unless(ref($interface_data) eq "HASH");

  %system_database = @inargs[0..2*$n_system-1];
  %thorns = @inargs[2*$n_system..$#inargs];
  @thorns = sort keys %thorns;

  my $peg_file = $ENV{CCTK_HOME}."/src/piraha/pegs/interface.peg";
  my ($grammar,$rule) = piraha::parse_peg_file($peg_file);

  #  Loop through each  thorn's interface file.
  foreach my $thorn (@thorns)
  {
    print "   $thorn\n";
    #       Get the arrangement name for the thorn
    $thorns{$thorn} =~ m:.*/arrangements/([^/]*)/[^/]*:;
    my $arrangement = $1;

    #       Read the data
    $ccl_file = "$thorns{$thorn}/interface.ccl";
    my @indata = &read_file($ccl_file);
    my $p=piraha::parse_src($grammar,$rule,$ccl_file);
    my $m = $p->matches();
    unless($m) {
      print "CST ERROR IN FILE '$ccl_file' ";
      $p->showError();
      confess("Parse Error");
    }
    if(defined($ENV{MAKE_TREE})) {
      my $fd = new FileHandle;
      open($fd,">tree.txt");
      print $fd $ccl_file,"\n";
      print $fd "=" x 50,"\n";
      print $fd $p->{gr}->dump(),"\n";
      close($fd);
    }

    #       Get the interface data from it
    &parse_interface_ccl($arrangement, $thorn, \@indata, $p->{gr}, $interface_data);

    &PrintInterfaceStatistics($thorn, $interface_data);
  }

  &cross_index_interface_data (\@thorns, $interface_data);

  print "+============================+\n";
  print "| Interface Parsing Complete |\n";
  print "+============================+\n";
}



sub cross_index_interface_data
{
  my($thorns_ref, $interface_data_ref) = @_;
  my(%implementations);
  my($implementation);
  my(%ancestors);
  my(%friends);
  my($thorn,$thorn_implements,$ancestor_imp,$thorn_ancestor,$message,$hint);
  my(%thorn_ancestor);

  foreach $thorn (@$thorns_ref)
  {
    $implementation = $interface_data_ref->{"\U$thorn\E IMPLEMENTS"};
    if($implementation =~ m:^\s*$:)
    {
      $message = "Thorn $thorn doesn't specify an implementation";
      $hint = "All compiled thorns must specify an implementation in their interface.ccl file with the format IMPLEMENTS: <implementation>";
      &CST_error(0,$message,$hint,__LINE__,__FILE__);
      next;
    }

    # Put if statement around this to prevent perl -w from complaining.
    if($interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"})
    {
      $interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"} .= "$thorn ";
    }
    else
    {
      $interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"} = "$thorn ";
    }

    $implementations{"\U$implementation\E"} = "$implementation";
  }

  $interface_data_ref->{"THORNS"} = join(" ", @$thorns_ref);

  foreach $implementation (sort keys %implementations)
  {

    # Put if statement around this to prevent perl -w from complaining.
    if($interface_data_ref->{"IMPLEMENTATIONS"})
    {
      $interface_data_ref->{"IMPLEMENTATIONS"} .= $implementations{"\U$implementation\E"} . " ";
    }
    else
    {
      $interface_data_ref->{"IMPLEMENTATIONS"} = $implementations{"\U$implementation\E"} . " ";
    }

    &check_implementation_consistency($implementation, $interface_data_ref);

    my %ancestors = ();
    &get_implementation_ancestors($implementation, $interface_data_ref, \%ancestors);

    $interface_data_ref->{"IMPLEMENTATION \U$implementation\E ANCESTORS"} = join(" ",(sort keys %ancestors));

    $interface_data_ref->{"IMPLEMENTATION \U$implementation\E FRIENDS"} = &get_friends_of_me($implementation, \%implementations, $interface_data_ref);

  }

  # Create Hash table with thorns as ancestors
  foreach $thorn (@$thorns_ref)
  {
    $thorn_implements = $interface_data_ref->{"\U$thorn\E IMPLEMENTS"};
    foreach $ancestor_imp ( split(' ', $interface_data_ref->{"\U$thorn INHERITS\E"}))
    {
      next if($ancestor_imp eq '');
      $thorn_ancestor{uc($thorn)} .= $interface_data_ref->{"IMPLEMENTATION \U$ancestor_imp\E THORNS"}. ' ';
    }
  }

  # Call find_dep_cycles to find and report cycles
  $message = &find_dep_cycles(%thorn_ancestor);
  if ("" ne  $message)
  {
   $message  =~ s/^\s*//g;
   $message  =~ s/\s*$//g;
   $message =~ s/\s+/->/g;
   $message = "Found a cyclic dependency in implementation inheritance: ".$message."\n";
   &CST_error(0,$message,$hint,__LINE__,__FILE__);
  }

  foreach $thorn (@$thorns_ref)
  {
    &check_interface_consistency($thorn, $interface_data_ref);
  }

  foreach $implementation (sort keys %implementations)
  {
    my %friends = ();
    &get_implementation_friends($implementation, $interface_data_ref, \%friends);
    $interface_data_ref->{"IMPLEMENTATION \U$implementation\E FRIENDS"} = join(" ",(sort keys %friends));
  }
}


sub get_friends_of_me
{
  my ($implementation, $implementations_ref, $interface_data_ref) = @_;
  my @friends = ();

  foreach my $other_implementation (sort keys %$implementations_ref)
  {

    $interface_data_ref->{"IMPLEMENTATION \U$other_implementation\E THORNS"} =~ m:(\w+):;

    my $thorn = $1;

    foreach my $friend (split(" ", $interface_data_ref->{"\U$thorn\E FRIEND"}))
    {
      push (@friends, $other_implementation) if ($friend =~ m:$implementation:i);
    }
  }

  return join (' ', @friends);
}


sub get_implementation_friends
{
  my($implementation, $interface_data_ref, $friends_ref) = @_;

  $interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"} =~ m:(\w+):;

  my $thorn = $1;

  # Recurse
  foreach my $friend (split(" ", $interface_data_ref->{"\U$thorn\E FRIEND"}),
                      split(" ", $interface_data_ref->{"IMPLEMENTATION \U$implementation\E FRIENDS"}))
  {
    if(! $friends_ref->{"\U$friend\E"})
    {
      $friends_ref->{"\U$friend\E"} = 1;
      if(! $interface_data_ref->{"IMPLEMENTATION \U$friend\E THORNS"})
      {
        my $message = "$implementation is friends with $friend - non-existent implementation";
        &CST_error(0,$message,"",__LINE__,__FILE__);
        next;
      }
      &get_implementation_friends($friend, $interface_data_ref, $friends_ref);
    }
  }
}

sub get_implementation_ancestors
{
  my($implementation, $interface_data_ref, $ancestors_ref) = @_;
  my(%info);
  my $cctk_home = $ENV{CCTK_HOME};

  $interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"} =~ m:(\w+):;

  my $thorn = $1;

  # Recurse.
  foreach my $ancestor (split(" ", $interface_data_ref->{"\U$thorn\E INHERITS"}))
  {
    if(! $ancestors_ref->{"\U$ancestor\E"})
    {
      $ancestors_ref->{"\U$ancestor\E"} = 1;
      if(! $interface_data_ref->{"IMPLEMENTATION \U$ancestor\E THORNS"})
      {
        # Implementation not found; give extensive information
        %info = &buildthorns("$cctk_home/arrangements","thorns");
        my $suggest_thorns = "";
        foreach my $thorninfo (sort keys %info)
        {
         $info{"$thorninfo"} =~ /^([^\s]+)/;
         my $testimp = $1;
         if ($testimp =~ m:^$ancestor$:i)
         {
           $suggest_thorns .= "\n        $thorninfo";
         }
        }
        my $message = "$implementation (thorn $thorn) inherits from $ancestor\n";
        $message .= "     No thorn in your current ThornList implements $ancestor\n";
        $message .= "     Either remove $thorn, or add a thorn to your\n";
        $message .= "      ThornList implementing $ancestor\n";
        if ($suggest_thorns !~ m:^$:)
        {
          $message .= "     Available thorns in arrangements directory implementing $ancestor:";
          $message .= "$suggest_thorns";
        }
        else
        {
          $message .= "     No thorns in arrangements directory implement $ancestor";
        }
        &CST_error(0,$message,"",__LINE__,__FILE__);

        next;
      }

      &get_implementation_ancestors($ancestor, $interface_data_ref, $ancestors_ref);
    }
  }
}

sub check_implementation_consistency
{
  my($implementation, $interface_data_ref) = @_;
  my(@thorns);
  my($thorn);
  my($thing);
  my(%inherits);
  my(%friend);
  my(%public_groups);
  my(%private_groups);
  my(%protected_groups);
  my(%variables);
  my($n_errors);
  my($group);
  my(%attributes);

  # Find out which thorns provide this implementation.
  @thorns = split(" ", $interface_data_ref->{"IMPLEMENTATION \U$implementation\E THORNS"});

  if(scalar(@thorns) > 1)
  {
    foreach $thorn (@thorns)
    {
      # Record the inheritance
      foreach $thing (split(" ", $interface_data_ref->{"\U$thorn\E INHERITS"}))
      {
        if($thing =~ m:\w:)
        {
          # Put if statement around this to prevent perl -w from complaining.
          if($inherits{"\U$thing\E"})
          {
            $inherits{"\U$thing\E"} .= "$thorn ";
          }
          else
          {
            $inherits{"\U$thing\E"} = "$thorn ";
          }
        }
      }

      # Record the friends
      foreach $thing (split(" ", $interface_data_ref->{"\U$thorn\E FRIEND"}))
      {
        if($thing =~ m:\w:)
        {
          # Put if statement around this to prevent perl -w from complaining.
          if($friend{"\U$thing\E"})
          {
            $friend{"\U$thing\E"} .= "$thorn ";
          }
          else
          {
            $friend{"\U$thing\E"} = "$thorn ";
          }
        }
      }

      # Record the public groups
      foreach $thing (split(" ", $interface_data_ref->{"\U$thorn\E PUBLIC GROUPS"}))
      {
        if($thing =~ m:\w:)
        {
          # Put if statement around this to prevent perl -w from complaining.
          if($public_groups{"\U$thing\E"})
          {
            $public_groups{"\U$thing\E"} .= "$thorn ";
          }
          else
          {
            $public_groups{"\U$thing\E"} = "$thorn ";
          }
        }
      }

      # Record the protected groups
      foreach $thing (split(" ", $interface_data_ref->{"\U$thorn\E PROTECTED GROUPS"}))
      {
        if($thing =~ m:\w:)
        {
          # Put if statement around this to prevent perl -w from complaining.
          if($protected_groups{"\U$thing\E"})
          {
            $protected_groups{"\U$thing\E"} .= "$thorn ";
          }
          else
          {
            $protected_groups{"\U$thing\E"} = "$thorn ";
          }
        }
      }
    }

    my $n_thorns = @thorns;

    # Check the consistency of the inheritance
    foreach $thing (sort keys %inherits)
    {
      if(split(' ', $inherits{$thing}) != $n_thorns)
      {
        &CST_error(0,
                   "Inconsistent implementation of '$implementation' " .
                   "provided by thorns '@thorns': not all inherit '$thing'",
                   '', __LINE__, __FILE__);
        $n_errors++;
      }
    }

    # Check the consistency of the friendships
    foreach $thing (sort keys %friend)
    {
      if(split(" ", $friend{$thing}) != $n_thorns)
      {
        my $message  = "Inconsistent implementations of $implementation\n";
        $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
        $message .= "Not all are friends of: $thing";
        &CST_error(0,$message,"",__LINE__,__FILE__);
        $n_errors++;
      }
    }

    # Check the consistency of the public groups
    foreach $thing (sort keys %public_groups)
    {
      if(split(" ", $public_groups{$thing}) != $n_thorns)
      {
          my $message  = "Inconsistent implementations of $implementation\n";
          $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
          $message .= "Not all declare public group: $thing";
          &CST_error(0,$message,"",__LINE__,__FILE__);
          $n_errors++;
      }
    }

    # Check the consistency of the protected groups
    foreach $thing (sort keys %protected_groups)
    {
      if(split(" ", $protected_groups{$thing}) != $n_thorns)
      {
        my $message  = "Inconsistent implementations of $implementation\n";
        $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
        $message .= "Not all declare protected group: $thing";
        &CST_error(0,$message,"",__LINE__,__FILE__);
        $n_errors++;
      }
    }

    # Check consistancy of group definitions
    foreach $group ((sort keys %public_groups), (sort keys %protected_groups))
    {
      %variables = ();
      %attributes = ();

      foreach $thorn (@thorns)
      {
        # Remember which variables are defined in this group.
        foreach $thing (split(" ",$interface_data_ref->{"\U$thorn GROUP $group\E"}))
        {
          # Put if statement around this to prevent perl -w from complaining.
          if($variables{"\U$thing\E"})
          {
            $variables{"\U$thing\E"} .= "$thorn ";
          }
          else
          {
            $variables{"\U$thing\E"} = "$thorn ";
          }
        }

        # Check variable type definition.
        if($attributes{"VTYPE"})
        {
          if($attributes{"VTYPE"} ne $interface_data_ref->{"\U$thorn GROUP $group\E VTYPE"})
          {
            my $message  = "Inconsistent implementations of $implementation";
            $message .= " in thorns " . join(" ", @thorns) . ". ";
            $message .= "Group $group has inconsistent variable type ($attributes{\"VTYPE\"} and $interface_data_ref->{\"\\U$thorn GROUP $group\\E VTYPE\"}). ";
            my $hint = "All public and protected groups implementing $implementation must have groups with consistent properties";
            &CST_error(0,$message,$hint,__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"VTYPE"} = $interface_data_ref->{"\U$thorn GROUP $group\E VTYPE"};
        }

        # Check group type definition.
        if($attributes{"GTYPE"})
        {
          if($attributes{"GTYPE"} ne $interface_data_ref->{"\U$thorn GROUP $group\E GTYPE"})
          {
            my $message  = "Inconsistent implementations of $implementation";
            $message .= " in thorns " . join(" ", @thorns) . ". ";
            $message .= "Group $group has inconsistent group type ($attributes{\"GTYPE\"} and $interface_data_ref->{\"\U$thorn GROUP $group\E GTYPE\"}). ";
            my $hint = "All public and protected groups implementing $implementation must have groups with consistent properties";
            &CST_error(0,$message,$hint,__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"GTYPE"} = $interface_data_ref->{"\U$thorn GROUP $group\E GTYPE"};
        }

        # Check the number of time levels is consistent.
        if($attributes{"TIMELEVELS"})
        {
          if($attributes{"TIMELEVELS"} ne $interface_data_ref->{"\U$thorn GROUP $group\E TIMELEVELS"})
          {
            my $message  = "Inconsistent implementations of $implementation\n";
            $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
            $message .= "Group $group has inconsistent time levels";
            &CST_error(0,$message,"",__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"TIMELEVELS"} = $interface_data_ref->{"\U$thorn GROUP $group\E TIMELEVELS"};
        }

        # Check the size array sizes are consistent.
        if($attributes{"SIZE"})
        {
          if($attributes{"SIZE"} ne $interface_data_ref->{"\U$thorn GROUP $group\E SIZE"})
          {
            my $message  = "Inconsistent implementations of $implementation\n";
            $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
            $message .= "Group $group has inconsistent size";
            &CST_error(0,$message,"",__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"SIZE"} = $interface_data_ref->{"\U$thorn GROUP $group\E SIZE"};
        }

        # Check the ghostsize array sizes are consistent.
        if($attributes{"GHOSTSIZE"})
        {
          if($attributes{"GHOSTSIZE"} ne $interface_data_ref->{"\U$thorn GROUP $group\E GHOSTSIZE"})
          {
            my $message  = "Inconsistent implementations of $implementation\n";
            $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
            $message .= "Group $group has inconsistent ghostsize";
            &CST_error(0,$message,"",__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"GHOSTSIZE"} = $interface_data_ref->{"\U$thorn GROUP $group\E GHOSTSIZE"};
        }

        # Check the distribution of arrays are consistent.
        if($attributes{"DISTRIB"})
        {
          if($attributes{"DISTRIB"} ne $interface_data_ref->{"\U$thorn GROUP $group\E DISTRIB"})
          {
            my $message  = "Inconsistent implementations of $implementation\n";
            $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
            $message .= "      Group $group has inconsistent distribution";
            &CST_error(0,$message,"",__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"DISTRIB"} = $interface_data_ref->{"\U$thorn GROUP $group\E DISTRIB"};
        }

        # Check the dimensions are consistant
        if($attributes{"DIM"} && $attributes{"GTYPE"} ne "SCALAR")
        {
          if($attributes{"DIM"} ne $interface_data_ref->{"\U$thorn GROUP $group\E DIM"})
          {
            my $message  = "Inconsistent implementations of $implementation\n";
            $message .= "Implemented by thorns " . join(" ", @thorns) . "\n";
            $message .= "Group $group has inconsistent dimension";
            &CST_error(0,$message,"",__LINE__,__FILE__);
            $n_errors++;
          }
        }
        else
        {
          $attributes{"DIM"} = $interface_data_ref->{"\U$thorn GROUP $group\E DIM"};
        }
      }
    }
  }
  else
  {
    # No need to do a consistency check if only one thorn
    # provides this implementation.

  }

}


#/*@@
#  @routine    check_interface_consistency
#  @date       Sun Jun 3 2001
#  @author     Gabrielle Allen
#  @desc
#  Check consistency of the interfaces files
#  @enddesc
#@@*/

sub check_interface_consistency
{
  my($thorn, $interface_data_ref) = @_;
  my($implementation);
  my($group,$var1,$var2,$group1,$group2);
  my($ancestor_imp,$ancestor_thorn,$ancestor2_imp,$ancestor2);
  my($message);

  # Find implementation
  $implementation =  $interface_data_ref->{"\U$thorn\E IMPLEMENTS"};

  # Loop over ancestors
  foreach $ancestor_imp (split " ",$interface_data_ref->{"IMPLEMENTATION \U$implementation\E ANCESTORS"})
  {
    # Need one thorn which implements this ancestor (we already have checked consistency)
    $ancestor_thorn = $interface_data_ref->{"IMPLEMENTATION \U$ancestor_imp\E THORNS"};
    if ($ancestor_thorn =~ m:(\w+)[^\w]*:)
    {
      $ancestor_thorn = $1;
    }
    foreach $group1 (split ' ', $interface_data_ref->{"\U$ancestor_thorn\E PUBLIC GROUPS"})
    {
      foreach $var1 (split ' ', $interface_data_ref->{"\U$ancestor_thorn\E GROUP \U$group1\E"})
      {
        foreach $ancestor2_imp (split " ",$interface_data_ref->{"IMPLEMENTATION \U$implementation\E ANCESTORS"})
        {
          $ancestor2 = $interface_data_ref->{"IMPLEMENTATION \U$ancestor2_imp\E THORNS"};
          if ($ancestor2 =~ m:(\w+)[^\w]*:)
          {
            $ancestor2 = $1;
          }
          # skip the second ancestor if it is the first one
          next if (uc($ancestor2) eq uc($ancestor_thorn));

          foreach $group2 (split ' ', $interface_data_ref->{"\U$ancestor2\E PUBLIC GROUPS"})
          {
            if (uc($group1) eq uc($group2))
            {
              $message = "Group $group1 from ancestor implementation $ancestor_imp in thorn $thorn has same name as \n     a public group: $group2 in ancestor implementation $ancestor2_imp (e.g. thorn $ancestor2)";
              &CST_error(1,$message,"",__LINE__,__FILE__);
            }
            if (uc($var1) eq uc($group2))
            {
              $message = "Variable $var1 in group $group1 from ancestor implementation $ancestor_imp in thorn $thorn has same name as \n     a public group: $group2 in ancestor implementation $ancestor2_imp (e.g. thorn $ancestor2)";
              &CST_error(1,$message,"",__LINE__,__FILE__);
            }
            foreach $var2 (split ' ', $interface_data_ref->{"\U$ancestor2\E GROUP \U$group2\E"})
            {
              if (uc($var2) eq uc($var1))
              {
                $message = "Variable $var1 in group $group1 from ancestor $ancestor_imp in thorn $thorn has same name as \n     variable $var2 in public group: $group2 in ancestor implementation $ancestor2_imp (e.g. thorn $ancestor2)";
                &CST_error(0,$message,"",__LINE__,__FILE__);
              }
            }
          }
        }
      }
    }

    foreach $group (split " ",$interface_data_ref->{"\U$thorn\E PRIVATE GROUPS"} . ' '. $interface_data_ref->{"\U$thorn\E PUBLIC GROUPS"} )
    {
      if ($interface_data_ref->{"\U$ancestor_thorn\E PUBLIC GROUPS"} =~ m:(\b$group\b):)
      {
        $message = "Group $group in thorn $thorn has same name as \n     public group in ancestor implementation $ancestor_imp (e.g. thorn $ancestor_thorn)";
        &CST_error(0,$message,"",__LINE__,__FILE__);
      }
      foreach my $var (split " ", $interface_data_ref->{"\U$thorn\E GROUP \U$group\E"})
      {
        foreach my $pub_anc (split " ", $interface_data_ref->{"\U$ancestor_thorn\E PUBLIC GROUPS"})
        {
          if ($interface_data_ref->{"\U$ancestor_thorn\E GROUP \U$pub_anc\E"} =~  m/\b$var\b/i)
          {
            my $message = "Variable $var in group $group in thorn $thorn has same name as \n     a variable in public group: $pub_anc in ancestor implementation $ancestor_imp (e.g. thorn $ancestor_thorn)";
            &CST_error(0,$message,"",__LINE__,__FILE__);
          }

        }


      }

    }
  }
}


sub print_args
{
  my $arg = shift;
  my $nm = $arg->{name};
  if($nm eq "intent" or $nm eq "arg_type" or $nm eq "cctk_fpointer" or $nm eq "array") {
    return uc($arg->substring());
  } elsif($nm eq "name") {
    return $arg->substring();
  } elsif($nm eq "args") {
    my $buf = "";
    for(my $i=0;$i < $arg->groupCount();$i++) {
      $buf .= ", " if($i > 0);
      $buf .= print_args($arg->group($i));
    }
    return $buf;
  } elsif($nm eq "arg") {
    my $buf = "";
    for(my $i=0;$i < $arg->groupCount();$i++) {
      $buf .= " " if($i > 0);
      $buf .= print_args($arg->group($i));
    }
    return $buf;
  } elsif($nm eq "fpointer") {
    my $buf .= print_args($arg->group(0));
    for(my $i=1;$i<$arg->groupCount()-1;$i++) {
      $buf .= " ";
      $buf .= print_args($arg->group($i));
    }
    $buf .= "(";
    $buf .= print_args($arg->group(-1));
    $buf .= ")";
    return $buf;
  }
  confess("not support arg($nm):$arg");
}

#/*@@
#  @routine    parse_interface_ccl
#  @date       Wed Sep 16 15:07:11 1998
#  @author     Tom Goodale
#  @desc
#  Parses an interface.ccl file and generates a database of the values.
#  @enddesc
#@@*/

sub parse_interface_ccl
{
  my($arrangement, $thorn, $data_ref, $group, $interface_data_ref) = @_;
  my($line_number, $line, $block, $type, $variable, $description);
  my($data);
  my($implementation);
  my($option,%options);
  my(%known_groups);
  my(%known_variables);

  # Initialise some stuff to prevent perl -w from complaining.
  
  my $interface_data_ref1 = {};

  $interface_data_ref1->{"\U$thorn INHERITS\E"} = "";
  $interface_data_ref1->{"\U$thorn FRIEND\E"} = "";
  $interface_data_ref1->{"\U$thorn PUBLIC GROUPS\E"} = "";
  $interface_data_ref1->{"\U$thorn PROTECTED GROUPS\E"} = "";
  $interface_data_ref1->{"\U$thorn PRIVATE GROUPS\E"} = "";
  $interface_data_ref1->{"\U$thorn USES HEADER\E"} = "";
  $interface_data_ref1->{"\U$thorn FUNCTIONS\E"} = "";
  $interface_data_ref1->{"\U$thorn PROVIDES FUNCTION\E"} = " ";
  $interface_data_ref1->{"\U$thorn REQUIRES FUNCTION\E"} = " ";
  $interface_data_ref1->{"\U$thorn USES FUNCTION\E"} = " ";
  $interface_data_ref1->{"\U$thorn ARRANGEMENT\E"} = "$arrangement";

  my $access = "PRIVATE";

  for my $fgroup (@{$group->{children}}) {
    my $fin =  $fgroup->{children}->[0];
    if($fin->is("IMPLEMENTS")) {
      $interface_data_ref1->{"\U$thorn\E IMPLEMENTS"} = $fin->group(0,"name")->substring();
    } elsif($fin->is("INHERITS")) {
      for my $ch (@{$fin->{children}}) {
        $interface_data_ref1->{"\U$thorn\E INHERITS"} .= $ch->substring()." ";
      }
    } elsif($fin->is("FRIEND")) {
      for my $ch (@{$fin->{children}}) {
        $interface_data_ref1->{"\U$thorn\E FRIEND"} .= $ch->substring()." ";
      }
    } elsif($fin->is("INCLUDE")) {
      my $wh = lc($fin->group(0,"what")->substring());
      my $h1 = $fin->group(1,"filename")->substring();
      my $h2 = $fin->group(2,"filename")->substring();
      if($wh eq "header" or $wh eq "") {
        $interface_data_ref1->{"\U$thorn ADD HEADER\E"} .= " ".$h1;
        $interface_data_ref1->{"\U$thorn ADD HEADER $h1 TO\E"} = $h2;
      } elsif($wh eq "source") {
        $interface_data_ref1->{"\U$thorn ADD SOURCE\E"} .= $h1." ";
        $interface_data_ref1->{"\U$thorn ADD SOURCE $h1 TO\E"} = $h2;
      } else {
        confess $fin->dump();
      }
    } elsif($fin->is("FUNCTION")) {
      my $func = $fin->group(0);
      if($func->is("FUNCTION_ALIAS")) {
        my $ret = $func->group(0)->substring();
        if($ret ne "void") {
          $ret = uc($ret);
        }
        $ret = "void" if($ret eq "SUBROUTINE");
        my $name = $func->group(1,"name")->substring();
        my $args = $func->group(2,"args");
        die $func->dump() unless(defined($args));
        $interface_data_ref1->{"\U$thorn\E FUNCTIONS"} .= $name." ";
        $interface_data_ref1->{"\U$thorn\E FUNCTION $name RET"} = $ret;
        $interface_data_ref1->{"\U$thorn\E FUNCTION $name ARGS"} = print_args($args);
      } elsif($func->is("PROVIDES_FUN")) {
        my $fname = $func->group(0,"name")->substring();
        my $with  = $func->group(1,"name")->substring();
        my $lang  = $func->group(2,"LANG")->substring();
        $interface_data_ref1->{"\U$thorn\E PROVIDES FUNCTION"} .= $fname." ";
        $interface_data_ref1->{"\U$thorn\E PROVIDES FUNCTION $fname LANG"} = $lang;
        $interface_data_ref1->{"\U$thorn\E PROVIDES FUNCTION $fname WITH"} = $with;
      } elsif($func->is("REQUIRES_FUN")) {
        my $fname = $func->group(0,"name")->substring();
        $interface_data_ref1->{"\U$thorn\E REQUIRES FUNCTION"} .= $fname." ";
      } elsif($func->is("USES")) {
        my $sub = $func->group(0);
        if($sub->is("USES_FUN")) {
          my $fname = $sub->group(0,"name")->substring();
          $interface_data_ref1->{"\U$thorn\E USES FUNCTION"} .= $fname." ";
        } else { # USES_INC
          my @ch = @{$sub->{children}};
          my $what = uc($sub->group(0,"what")->substring());
          if($what eq "HEADER" or $what eq "") {
            for(my $i=1;$i<$sub->groupCount();$i++) {
              $interface_data_ref1->{"\U$thorn\E USES HEADER"} .= $sub->group($i,"filename")->substring()." ";
            }
          } elsif($what eq "SOURCE") {
            for(my $i=1;$i<$sub->groupCount();$i++) {
              $interface_data_ref1->{"\U$thorn\E USES SOURCE"} .= $sub->group($i,"filename")->substring()." ";
            }
          }
        }
      }
    } elsif($fin->is("access")) {
      $access = $fin->substring();
    } elsif($fin->is("GROUP_VARS")) {
      my $vtype = uc($fin->group(0,"vtype")->substring());
      my $gname = $fin->group(1,"gname")->group(0,"name")->substring();
      my $desc = undef;
      my $dim = undef;
      my $distrib = undef;
      my $gtype = undef;
      my $tags = undef;
      my $timelevels = 1;
      my $size = undef;
      my $var_array_size = undef;
      if($fin->group(1,"gname")->has(1,"expr")) {
        $var_array_size = expr($fin->group(1)->group(1));
      }
      $interface_data_ref1->{"\U$thorn $access GROUPS\E"} .= " ".$gname;
      $interface_data_ref1->{"\U$thorn GROUP $gname\E"} = $gname;
      my %items = ();
      for(my $i=2;$i<$fin->groupCount();$i++) {
        my $ch=$fin->group($i);
        my $nm = $ch->{name};
        if(defined($items{$nm})) {
          print "CST Error:\n";
          print "Repeated element 'tag' in $gname\n";
          print "Line: ",$ch->linenum(),"\n";
          print "File: ",$ccl_file,"\n";
          confess("Repeated item: $nm in $gname")
        }
        $items{$nm}++;
        if($nm eq "desc" or $nm eq "group_comment") {
          my $new_desc = trim_quotes($ch->substring());
          $desc .= $new_desc;
        } elsif($nm eq "timelevels") {
          $timelevels = $ch->substring();
        } elsif($nm eq "dim") {
          $dim = $ch->substring();
        } elsif($nm eq "size") {
          my $sz = "";
          my $ndims = 0;
          for my $c (@{$ch->{children}}) {
            $sz .= "," unless($sz eq "");
            $sz .= uc(expr($c));
            $ndims++;
          }
          $size = $sz;
          $dim = $ndims;
        } elsif($nm eq "distrib") {
          $distrib = uc($ch->substring());
        } elsif($nm eq "gtype") {
          $gtype = uc($ch->substring());
        } elsif($nm eq "VARS") {
          $interface_data_ref1->{"\U$thorn GROUP $gname\E"} = "";
          for my $c (@{$ch->{children}}) {
            $interface_data_ref1->{"\U$thorn GROUP $gname\E"} .= " ".$c->substring();
          }
        } elsif($nm eq "ghostsize") {
          my $ghost = "";
          for my $c (@{$ch->{children}}) {
            $ghost .= "," unless($ghost eq "");
            $ghost .= expr($c);
          }
          $interface_data_ref1->{"\U$thorn GROUP $gname GHOSTSIZE\E"} = uc($ghost);
        } elsif($nm eq "tags") {
          my $new_tags = trim_quotes($ch->substring());
          $new_tags =~ s/"/\\"/g;
          $tags = $new_tags;
        }
      }
      # Fill in default values
      $gtype = "SCALAR" if(!defined($gtype));
      $dim = 0 if(!defined($dim) and $gtype eq "SCALAR");
      $dim = 3 if(!defined($dim) and $gtype eq "GF");
      $distrib = "DEFAULT" if(!defined($distrib) and ($gtype eq "GF" or $gtype eq "ARRAY"));
      $distrib = "CONSTANT" if(!defined($distrib));
      # TODO: What is this?
      $interface_data_ref1->{"\U$thorn GROUP $gname COMPACT\E"} = 0;
      $interface_data_ref1->{"\U$thorn GROUP $gname DIM\E"} = $dim;
      if(defined($desc) and $desc !~ /^\s*$/) {
        $interface_data_ref1->{"\U$thorn GROUP $gname DESCRIPTION\E"} = $desc;
      }
      $interface_data_ref1->{"\U$thorn GROUP $gname DISTRIB\E"} = $distrib;
      $interface_data_ref1->{"\U$thorn GROUP $gname GTYPE\E"} = $gtype;
      if(defined($tags)) {
        $interface_data_ref1->{"\U$thorn GROUP $gname TAGS\E"} = $tags;
      }
      $interface_data_ref1->{"\U$thorn GROUP $gname TIMELEVELS\E"} = $timelevels;
      $interface_data_ref1->{"\U$thorn GROUP $gname VTYPE\E"} = $vtype;
      if(defined($size)) {
        $interface_data_ref1->{"\U$thorn GROUP $gname SIZE\E"} = $size;
      }
      if(defined($var_array_size)) {
        $interface_data_ref1->{"\U$thorn GROUP $gname VARARRAY_SIZE\E"} = $var_array_size;
      }
    }
  }

  # Initialise some stuff to prevent perl -w from complaining.

  my $interface_data_ref2 = {};

  $interface_data_ref2->{"\U$thorn INHERITS\E"} = "";
  $interface_data_ref2->{"\U$thorn FRIEND\E"} = "";
  $interface_data_ref2->{"\U$thorn PUBLIC GROUPS\E"} = "";
  $interface_data_ref2->{"\U$thorn PROTECTED GROUPS\E"} = "";
  $interface_data_ref2->{"\U$thorn PRIVATE GROUPS\E"} = "";
  $interface_data_ref2->{"\U$thorn USES HEADER\E"} = "";
  $interface_data_ref2->{"\U$thorn FUNCTIONS\E"} = "";
  $interface_data_ref2->{"\U$thorn PROVIDES FUNCTION\E"} = " ";
  $interface_data_ref2->{"\U$thorn REQUIRES FUNCTION\E"} = " ";
  $interface_data_ref2->{"\U$thorn USES FUNCTION\E"} = " ";
  $interface_data_ref2->{"\U$thorn ARRANGEMENT\E"} = "$arrangement";

  #   The default block is private.
  $block = "PRIVATE";

  for($line_number = 0; $line_number < @$data_ref; $line_number++)
  {
    $line = $data_ref->[$line_number];

    #       Parse the line
    if($line =~ m/^\s*(PUBLIC|PROTECTED|PRIVATE)\s*$/i)
    {
      #           It's a new block.
      $block = "\U$1\E";
    }
    elsif ($line =~ m/^\s*IMPLEMENTS\s*:/i)
    {
      if ($line =~ m/^\s*IMPLEMENTS\s*:\s*([a-z]+[a-z_0-9]*)\s*$/i)
      {
        if(!$implementation)
        {
          $implementation = $1;
          $interface_data_ref2->{"\U$thorn\E IMPLEMENTS"} = $implementation;
        }
        else
        {
          my $message = "Multiple implementations specified in $thorn";
          my $hint = "A thorn can only specify one implementation in its interface.ccl file, with the format implements:<implementation>";
          &CST_error(0,$message,$hint,__LINE__,__FILE__);
        }
      }
      else
      {
        my $message = "Implementation line has wrong format in $thorn";
        my $hint = "A thorn must specify one implementation in its interface.ccl file with the format IMPLEMENTS: <implementation>";
        &CST_error(0,$message,$hint,__LINE__,__FILE__);
      }
    }
    # implementation names can be separated by ,\s, where , are stripped out below
    elsif ($line =~ m/^\s*(INHERITS|FRIEND)\s*:(([,\s]*[a-zA-Z]+[a-zA-Z_0-9]*)*[,\s]*)$/i)
    {
      $interface_data_ref2->{"\U$thorn $1\E"} .= $2;
      $interface_data_ref2->{"\U$thorn $1\E"}=~s/,/ /g;
    }
    elsif ($line =~ m/^\s*(PUBLIC|PROTECTED|PRIVATE)\s*:\s*$/i)
    {
      $block = "\U$1\E";
    }
    elsif ($line =~ m/^\s*PROVIDES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*WITH\s*(.+)\s*$/i)
    {
      my $funcname = $1;
      my $provided_by = $2;
      my $provided_by_language;

      if($provided_by =~ m/^(.*)\s+LANGUAGE\s+(.*\S)\s*$/i)
      {
        $provided_by          = $1;
        $provided_by_language = "\U$2";
        if ($provided_by_language eq 'FORTRAN')
        {
          $provided_by_language = 'Fortran';
        }
        elsif ($provided_by_language ne 'C')
        {
          my $message = "The providing function $provided_by in thorn $thorn " .
                        "has an invalid language specification.";
          my $hint = "Language must be either C or Fortran.";
          &CST_error(0, $message, $hint, __LINE__, __FILE__);
        }
      }
      else
      {
#        $provided_by_language = "Fortran";
#        $provided_by_language = "C";
        my $message = "The providing function $provided_by in thorn $thorn does not have a specified language. Please add, e.g., \"LANGUAGE C\"";
        &CST_error(0,$message,"",__LINE__,__FILE__);

      }

      if($funcname eq $provided_by) {
        my $message = "The providing function $provided_by in thorn $thorn " .
                      "has a name that is identical to the name of the provided " .
                      "function $funcname. The names must be different.";
        my $hint = "Rename the providing function by prefixing its name with ".
                   "'${thorn}_'.";
        &CST_error(0, $message, $hint, __LINE__, __FILE__);
      }

      $interface_data_ref2->{"\U$thorn PROVIDES FUNCTION\E"} .= "$funcname ";
      $interface_data_ref2->{"\U$thorn PROVIDES FUNCTION\E $funcname WITH"} .= "$provided_by ";
      $interface_data_ref2->{"\U$thorn PROVIDES FUNCTION\E $funcname LANG"} .= "$provided_by_language ";

    }
    elsif ($line =~ m/^\s*REQUIRES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*$/i)
    {
      my$funcname = $1;
      $interface_data_ref2->{"\U$thorn REQUIRES FUNCTION\E"} .= "$funcname ";
    }
    elsif ($line =~ m/^\s*USES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*$/i)
    {
      my $funcname = $1;
      $interface_data_ref2->{"\U$thorn USES FUNCTION\E"} .= "$funcname ";
    }
    elsif ($line =~ m/^\s*([a-zA-Z][a-zA-Z_0-9:]+)\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*\((.*)\)\s*$/i)
    {
      my $rettype  = $1;
      my $funcname = $2;
      my $rest     = $3;

      my $funcargs = $rest;

      $interface_data_ref2->{"\U$thorn FUNCTIONS\E"} .= "${funcname} ";
      $interface_data_ref2->{"\U$thorn FUNCTION\E $funcname ARGS"} .= "${funcargs} ";
      $interface_data_ref2->{"\U$thorn FUNCTION\E $funcname RET"} .= "${rettype} ";
    }
    elsif ($line =~ m/^\s*SUBROUTINE\s*([a-zA-Z_0-9]+)\s*\((.*)\)\s*$/i)
    {
      my $rettype  = "void";
      my $funcname = $1;
      my $rest     = $2;

      my $funcargs = $rest;

      $interface_data_ref2->{"\U$thorn FUNCTIONS\E"} .= "${funcname} ";
      $interface_data_ref2->{"\U$thorn FUNCTION\E $funcname ARGS"} .= "${funcargs} ";
      $interface_data_ref2->{"\U$thorn FUNCTION\E $funcname RET"} .= "${rettype} ";
    }
    elsif ($line =~ m/^\s*(CCTK_)?(CHAR|BYTE|INT|INT1|INT2|INT4|INT8|INT16|REAL|REAL4|REAL8|REAL16|COMPLEX|COMPLEX8|COMPLEX16|COMPLEX32)\s*(([a-zA-Z][a-zA-Z_0-9]*)\s*(\[([^]]+)\])?)\s*(.*)\s*$/i)
    {
#      for($i = 1; $i < 10; $i++)
#      {
#        print "$i is ${$i}\n";
#      }
      my $vtype = $2;
      my $current_group = "$4";
      my $isgrouparray = $5;
      my $grouparray_size = $6;
      my $options_list = $7;

#      print "line is [$line]\n";
#      print "group name is [$current_group]\n";
#      print "options list is [$options_list]\n";

      if($known_groups{"\U$current_group\E"})
      {
        &CST_error(0,"Duplicate group $current_group in thorn $thorn",'',
                   __LINE__,__FILE__);
        if($data_ref->[$line_number+1] =~ m:\{:)
        {
            &CST_error(1,'Skipping interface block','',__LINE__,__FILE__);
            $line_number++ until ($data_ref->[$line_number] =~ m:\}:);
        }
        next;
      }
      else
      {
        $known_groups{"\U$current_group\E"} = 1;

        # Initialise some stuff to prevent perl -w from complaining.
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E"} = "";
      }

      $interface_data_ref2->{"\U$thorn $block GROUPS\E"} .= " $current_group";
      $interface_data_ref2->{"\U$thorn GROUP $current_group\E VTYPE"} = "\U$vtype\E";

      # Grab optional group description from end of $options_list
      if ($options_list =~ /(=?)\s*"([^"]*)"\s*$/)
      {
        if (!$1)
        {
          if ($data_ref->[$line_number+1] =~ m/^\s*\{\s*$/)
          {
            &CST_error(1,"Group description for $current_group in thorn " .
                       "$thorn must be placed at end of variable block " .
                       "when variable block present",'',
                       __LINE__,__FILE__);
          } else
          {
            $description = $2;
            my $quoted_description = quotemeta ($description);
            $options_list =~ s/\s*"$quoted_description"//;
          }
        }
      }

      # split(/\s*=\s*|\s+/, $options_list);
      %options = SplitWithStrings($options_list,$thorn);

      # Parse the options
      foreach $option (sort keys %options)
      {

#        print "DEBUG $option is $options{$option}\n";

        if($option =~ m:DIM|DIMENSION:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"} = $options{$option};
        }
        elsif($option =~ m:TYPE:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} = "\U$options{$option}\E";
        }
        elsif($option =~ m:TIMELEVELS:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E TIMELEVELS"} = "\U$options{$option}\E";
        }
        elsif($option =~ m:GHOSTSIZE:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E GHOSTSIZE"} = "\U$options{$option}\E";
        }
        elsif($option =~ m:DISTRIB:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} = "\U$options{$option}\E";
        }
        elsif($option =~ m:SIZE:i)
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E SIZE"} = "\U$options{$option}\E";
        }
        elsif($option =~ m:TAGS:i)
        {
          if($options{$option} =~ m/\s*^[\'\"](.*)[\'\"]$/)
          {
            $options{$option} = $1;
          }

          $options{$option} =~ s/\\/\\\\/g;
          $options{$option} =~ s/\"/\\\"/g;

          $interface_data_ref2->{"\U$thorn GROUP $current_group\E TAGS"} = $options{$option};
        }
        else
        {
          &CST_error(0,"Unknown option \"$option\" in group $current_group in interface.ccl for " .
                     "of thorn $thorn\n     Perhaps you forgot a '\\' at the " .
                     "end of a continued line?\n" .
                     "The offending line is '$line'\n",'',
                     __LINE__,__FILE__);
        }
      }

      # Put in defaults
      if(! $interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"})
      {
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} = "SCALAR";
      }

      if (! $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"})
      {
        if ($interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} eq 'SCALAR')
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"} = 0;
        }
        else
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"} = 3;
        }
      }

      if(! $interface_data_ref2->{"\U$thorn GROUP $current_group\E TIMELEVELS"})
      {
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E TIMELEVELS"} = 1;
      }

      if(! $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"})
      {
        if ($interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} eq 'SCALAR')
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} = 'CONSTANT';
        }
        else
        {
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} = 'DEFAULT';
        }
      }

      if(! $interface_data_ref2->{"\U$thorn GROUP $current_group\E COMPACT"})
      {
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E COMPACT"} = 0;
      }

      if ($interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} eq "SCALAR")
      {
        my $dim = $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"};
        if ($dim && $dim ne '0')
        {
          my $message =  "Inconsistent GROUP DIM $dim for SCALAR group $current_group of thorn $thorn";
          my $hint = "The only allowed group dimension for scalar groups is '0'";
          &CST_error (0, $message, $hint, __LINE__, __FILE__);
          if ($data_ref->[$line_number+1] =~ m:\{:)
          {
            &CST_error (1, "Skipping interface block in $thorn", '',
                        __LINE__, __FILE__);
            ++ $line_number until ($data_ref->[$line_number] =~ m:\}:);
          }
          next;
        }
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E DIM"} = 0;

        my $distrib = $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"};
        if ($distrib && $distrib ne 'CONSTANT')
        {
          my $message =  "Inconsistent GROUP DISTRIB $distrib for SCALAR group $current_group of thorn $thorn";
          my $hint = "The only allowed group distribution for scalar groups is 'CONSTANT'";
          &CST_error (0, $message, $hint, __LINE__, __FILE__);
          if ($data_ref->[$line_number+1] =~ m:\{:)
          {
            &CST_error (1, "Skipping interface block in $thorn", '',
                        __LINE__, __FILE__);
            ++ $line_number until ($data_ref->[$line_number] =~ m:\}:);
          }
          next;
        }
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} =
            "CONSTANT";
      }

      # Override defaults for grid functions
      if ($interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} eq "GF")
      {
        my $distrib = $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"};
        if ($distrib && $distrib ne 'DEFAULT')
        {
          my $message =  "Inconsistent GROUP DISTRIB $distrib for GF group $current_group of thorn $thorn";
          my $hint = "The only allowed group distribution for grid function groups is 'DEFAULT'";
          &CST_error (0, $message, $hint, __LINE__, __FILE__);
          if ($data_ref->[$line_number+1] =~ m:\{:)
          {
            &CST_error (1, "Skipping interface block in $thorn", '',
                        __LINE__, __FILE__);
            ++ $line_number until ($data_ref->[$line_number] =~ m:\}:);
          }
          next;
        }
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} =
            "DEFAULT";
      }

      # Check that it is a known group type
      if($interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} !~ m:^\s*(SCALAR|GF|ARRAY)\s*$:)
      {
          my $message =  "Unknown GROUP TYPE " .
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E GTYPE"} .
            " for group $current_group of thorn $thorn";
          my $hint = "Allowed group types are SCALAR, GF or ARRAY";
          &CST_error(0,$message,$hint,__LINE__,__FILE__);
          if($data_ref->[$line_number+1] =~ m:\{:)
          {
              &CST_error(1,"Skipping interface block in $thorn","",
                         __LINE__,__FILE__);
              $line_number++ until ($data_ref->[$line_number] =~ m:\}:);
          }
        next;
      }

      # Check that it is a known distribution type
      if($interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} !~ m:DEFAULT|CONSTANT:)
      {
          my $message =  "Unknown DISTRIB TYPE " .
          $interface_data_ref2->{"\U$thorn GROUP $current_group\E DISTRIB"} .
            " for group $current_group of thorn $thorn";
          my $hint = "Allowed distribution types are DEFAULT or CONSTANT";
          &CST_error(0,$message,"",__LINE__,__FILE__);
          if($data_ref->[$line_number+1] =~ m:\{:)
          {
              &CST_error(1,"Skipping interface block in $thorn",'',
                         __LINE__,__FILE__);
              $line_number++ until ($data_ref->[$line_number] =~ m:\}:);
          }
        next;
      }

      # Is it a vararray?
      if($isgrouparray)
      {
        # get its size
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E VARARRAY_SIZE"} = $grouparray_size;
      }
        # Fill in data for the scalars/arrays/functions
        $line_number++;
        if($data_ref->[$line_number] =~ m/^\s*\{\s*$/)
        {
          $line_number++;
          while($data_ref->[$line_number] !~ m:\}:i)
          {
            my @functions = split(/[^a-zA-Z_0-9]+/, $data_ref->[$line_number]);
            foreach my $function (@functions)
            {
              if ($function eq $current_group)
              {
                if ($#functions == 1)
                {
                  &CST_error(1,"Group and variable '$function' in thorn " .
                             "'$thorn' should be distinct",'',
                             __LINE__,__FILE__);
                }
                else
                {
                  &CST_error(0,"The names of all variables '@functions' must " .
                             "be different from their group name " .
                             "'$current_group' in thorn '$thorn'",'',
                             __LINE__,__FILE__);
                }
              }
              $function =~ s:\s*::g;

              if($function =~ m:[^\s]+:)
              {
                if(! $known_variables{"\U$function\E"})
                {
                  $known_variables{"\U$function\E"} = 1;

                  $interface_data_ref2->{"\U$thorn GROUP $current_group\E"} .= " $function";
                }
                else
                {
                  &CST_error(0,"Duplicate variable $function in thorn $thorn",'',
                             __LINE__,__FILE__);
                }
              }
            }
            $line_number++;
          }
          # Grab optional group description
          $data_ref->[$line_number] =~ m:\}\s*"([^"]*)":;
          $description = $1;
        }
        else
        {
          # If no block, create a variable with the same name as group.
          my $function = $current_group;
          if(! $known_variables{"\U$function\E"})
          {
            $known_variables{"\U$function\E"} = 1;

            $interface_data_ref2->{"\U$thorn GROUP $current_group\E"} .= " $function";
          }
          else
          {
            &CST_error(0,"Duplicate variable $function in thorn $thorn",'',
                       __LINE__,__FILE__);
          }

          # Decrement the line number, since the line is the first line of the next CCL statement.
          $line_number--;
        }
        $interface_data_ref2->{"\U$thorn GROUP $current_group\E DESCRIPTION"} = $description;
        $description = ""; # Prevent re-use of description
    }
    elsif ($line =~ m/^\s*(USES\s*INCLUDE)S?\s*(SOURCE)S?\s*:\s*(.*)\s*$/i)
    {
      $interface_data_ref2->{"\U$thorn USES SOURCE\E"} .= " $3";
    }
    elsif ($line =~ m/^\s*(USES\s*INCLUDE)S?\s*(HEADER)?S?\s*:\s*(.*)\s*$/i)
    {
      $interface_data_ref2->{"\U$thorn USES HEADER\E"} .= " $3";
    }
    elsif ($line =~ m/^\s*(INCLUDE)S?\s*(SOURCE)S?\s*:\s*(.*)\s+IN\s+(.*)\s*$/i)
    {
      my $header = $3;
      $header =~ s/ //g;
      $interface_data_ref2->{"\U$thorn ADD SOURCE\E"} .= " $header";
#      print "Adding $header to $4\n";
      $interface_data_ref2->{"\U$thorn ADD SOURCE $header TO\E"} = $4;
    }
    elsif ($line =~ m/^\s*(INCLUDE)S?\s*(HEADER)?S?\s*:\s*(\S*)\s+IN\s+(\S*)\s*$/i)
    {
      my $header = $3;
      $header =~ s/ //g;
      $interface_data_ref2->{"\U$thorn ADD HEADER\E"} .= " $header";
#      print "Adding $header to $4\n";
      $interface_data_ref2->{"\U$thorn ADD HEADER $header TO\E"} = $4;
    }
    else
    {
      if($line =~ m:\{:)
      {
        &CST_error(0,'...Skipping interface block with missing keyword....','',
                   __LINE__,__FILE__);

        $line_number++ until ($data_ref->[$line_number] =~ m:\}:);
      }
      else
      {
        &CST_error(0,"Unknown line in interface.ccl for thorn $arrangement/$thorn\n\"$line\"",'',__LINE__,__FILE__) if ($line);
      }
    }
  }
  for my $k (sort keys %{$interface_data_ref2}) {
    my $v1 = "".$interface_data_ref1->{$k};
    my $v2 = "".$interface_data_ref2->{$k};
    unless($v1 =~ /VOID/) {
      $v1 =~ s/\s+/\n/g;
      $v2 =~ s/\s+/\n/g;
      $v1 =~ s/\s+$//;
      $v2 =~ s/\s+$//;
      $v1 =~ s/^\s+//;
      $v2 =~ s/^\s+//;
      $v1 =~ s/\s\(/\(/g;
      $v2 =~ s/\s\(/\(/g;
      $v1 =~ s/\s*,\s*/,\n/g;
      $v2 =~ s/\s*,\s*/,\n/g;
    }
    my $fd = new FileHandle;
    open($fd,">v1") or die;
    print $fd $v1,"\n";
    close($fd);
    open($fd,">v2") or die;
    print $fd $v2,"\n";
    close($fd);
    if($v1 ne $v2) {
      confess("key error:($k) new=($v1) old=($v2)");
    }
  }
  for my $k (sort keys %{$interface_data_ref1}) {
    if(!defined($interface_data_ref2->{$k})) {
      confess("Extra key in interface ($k) ($interface_data_ref1->{$k})")
    }
  }
  for my $k (keys %{$interface_data_ref1}) {
    $interface_data_ref->{$k} .= $interface_data_ref1->{$k};
  }
}

#/*@@
#  @routine    PrintInterfaceStatistics
#  @date       Sun Sep 19 13:03:23 1999
#  @author     Tom Goodale
#  @desc
#  Prints out some statistics about a thorn's interface.ccl
#  @enddesc
#@@*/
sub PrintInterfaceStatistics
{
  my($thorn, $interface_database_ref) = @_;
  my($block);
  my($sep);

  print "           Implements: " . $interface_database_ref->{"\U$thorn IMPLEMENTS"} . "\n";

  if($interface_database_ref->{"\U$thorn INHERITS"} ne "")
  {
    print "           Inherits:  " . $interface_database_ref->{"\U$thorn INHERITS"} . "\n";
  }

  if($interface_database_ref->{"\U$thorn FRIEND"} ne "")
  {
    print "           Friend of: " . $interface_database_ref->{"\U$thorn FRIEND"} . "\n";
  }

  $sep = "           ";
  foreach $block ("Public", "Protected", "Private")
  {
    print $sep . scalar(split(" ", $interface_database_ref->{"\U$thorn $block\E GROUPS"})) . " $block";
    $sep = ", ";
  }

  print " variable groups\n";

  return;
}

1;
