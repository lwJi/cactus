	#! /usr/bin/perl
#/*@@
#  @file      ScheduleParser.pl
#  @date      Thu Sep 16 19:13:05 1999
#  @author    Tom Goodale
#  @desc
#             New schedule parser
#  @enddesc
#  @version   $Header$
#@@*/
use Data::Dumper;
use Carp;
use FileHandle;
*STDERR = *STDOUT;

my ($style1,$style2);
my ($buffer1,$buffer2);

my ($piraha_dir)=("$ENV{TOP}/piraha");
my ($schedules_dir)=("$piraha_dir/schedules");

sub incl {
    my $VAR;
    my $file = shift;
    local $/ = undef;
    my $fd = new FileHandle;
    unless(-r $file) {
        carp "File $file isn't readable";
    }
    open($fd,$file) or die "Cannot open $file";
    my $c = <$fd>;
    close($fd);
    eval $c;
    return $VAR;
}

# The known schedule bins
our @schedule_bins = (
    # Cactus startup
    'STARTUP',
    'WRAGH',
    'PARAMCHECK',
    # Initialisation
    'PREREGRIDINITIAL',
    'POSTREGRIDINITIAL',
    'BASEGRID',
    'INITIAL',
    'POSTRESTRICTINITIAL',
    'POSTINITIAL',
    'POSTPOSTINITIAL',
    # Recovery                  
    'RECOVER_VARIABLES',
    'POST_RECOVER_VARIABLES',
    'RECOVER_PARAMETERS',
    'CPINITIAL',
    # Evolution
    'PREREGRID',
    'POSTREGRID',
    'PRESTEP',
    'EVOL',
    'POSTRESTRICT',
    'POSTSTEP',
    'CHECKPOINT',
    'ANALYSIS',
    # Shutdown
    'TERMINATE',
    'SHUTDOWN');
# A regular expression matching all possible schedule bins, including
# a CCTK prefix and in upper case
our $schedule_bin_regexp = 'CCTK_(' . join ('|', @schedule_bins) . ')';



#/*@@
#  @routine    create_schedule_database
#  @date       Thu Sep 16 23:31:00 1999
#  @author     Tom Goodale
#  @desc
#  Parses the schedule files for all thorns.
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/
sub create_schedule_database
{
  my(%thorns) = @_;
  my($thorn, @indata);
  my(@new_schedule_data);
  my(@schedule_data);

  my ($indata);
  my (@new_schedule_data2);

  #  Loop through each implementation's schedule file.
  foreach $thorn (sort keys %thorns)
  {
    print "   $thorn\n";
    #       Read the data
    @indata = &read_file("$thorns{$thorn}/schedule.ccl");
    print "SCHEDULE FILE $thorns{$thorn}/schedule.ccl";

    #       Get the schedule stuff from it
    # indata already has comments removed!!!
    my %h1 = &parse_schedule_ccl($thorn, @indata);
    @new_schedule_data2 = %h1;
    #print "SCHEDULE_DUMP\n";
    #print Dumper(\@new_schedule_data,\$thorn,\@indata);


    #       Add the schedule stuff to the master schedule database
    push (@schedule_data, @new_schedule_data);

    # Version 2
    my %h2 = &parse_schedule_ccl2($thorn,"$thorns{$thorn}/schedule.ccl");
    @new_schedule_data = %h2;
    
#	die_compare ($style1, $style2);
#	die_compare ($buffer1, $buffer2);
#	print STDERR "OLDV:",Dumper(\@new_schedule_data),"\n";
#	print STDERR "NEWV:",Dumper(\%h2),"\n";
	
	my %k1 = ();
	for my $k (keys %h1) {
		$k1{$k}++;
	}
	my %k2 = ();
	for my $k (keys %h2) {
		$k2{$k}++;
	}
	my $success = 1;
    for my $k (keys %k1) {
    	my $v1 = $h1{$k};
    	my $v2 = $h2{$k};
    	if(!defined($k2{$k})) {
    		warn "Warn: Missing Key h1($k)=$h1{$k}\n";
    		$success = 0;
    	} elsif(defined($v1) and !defined($v2)) {
    		warn "Warn: h2{$k} is undefined";
    		$success = 0;
    	} elsif(!defined($v1) and defined($v2)) {
    		warn "Warn: h1{$k} is undefined";
    		$success = 0;
    	} elsif($h1{$k} ne $h2{$k}) {
#			die_compare($h1{$k},$h2{$k});
    	}
    }
    for my $k (keys %k2) {
    	if(!defined($k1{$k})) {
    		warn "Warn: Added Key h2($k)=$h2{$k}";
    		$success = 0;
    	} elsif(defined($v1) and !defined($v2)) {
    		warn "Warn: h2{$k} is undefined";
    		$success = 0;
    	} elsif(!defined($v1) and defined($v2)) {
    		warn "Warn: h1{$k} is undefined";
    		$success = 0;
    	} elsif($h1{$k} ne $h2{$k}) {
#			die_compare($h1{$k},$h2{$k});
    	}
    }
    if($#new_schedule_data2 != $#new_schedule_data) {
        warn "Warn: $#new_schedule_data2 != $#new_schedule_data";
    	$success = 0;
    }
#    print sort_dump(\%h1);
	die_compare(sort_dump(\%h1),sort_dump(\%h2));
    #die "NO SUCCESS" unless($success);
    
    &PrintScheduleStatistics($thorn, @new_schedule_data);
  }

#  @schedule_data = &cross_index_schedule_data(scalar(keys %thorns), (sort keys %thorns), @schedule_data);

  return @schedule_data;
}

#/*@@
#  @routine    parse_schedule_ccl
#  @date       Thu Sep 16 23:23:07 1999
#  @author     Tom Goodale
#  @desc
#  Parses a schedule ccl file
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/
sub parse_schedule_ccl
{
  my($thorn, @data) = @_;
  my($line_number);
  my(%schedule_db);
  my($buffer);
  my($n_blocks);
  my($n_statements);
  my($name, $as, $type, $description, $where, $language,
       $mem_groups, $comm_groups, $trigger_groups, $sync_groups,
       $options, $tags, $before_list, $after_list,
       $writes_list, $reads_list, $while_list, $if_list);
  my($groups);
  $style1 = "";

  $buffer       = "";
  $n_blocks     = 0;
  $n_statements = 0;

  for($line_number = 0; $line_number < scalar(@data); $line_number++)
  {
    if($data[$line_number] =~ m:^\s*schedule\s*:i)
    {
      ($line_number,
       $name, $as, $type, $description, $where, $language,
       $mem_groups, $comm_groups, $trigger_groups, $sync_groups,
       $options, $tags, $before_list, $after_list,
       $writes_list, $reads_list, $while_list, $if_list) =
           &ParseScheduleBlock($thorn,$line_number, @data);

      $schedule_db{"\U$thorn\E BLOCK_$n_blocks NAME"}        = $name;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks AS"}          = $as;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks TYPE"}        = $type;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks DESCRIPTION"} = $description;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks WHERE"}       = $where;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks LANG"}        = $language;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks STOR"}        = $mem_groups;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks COMM"}        = $comm_groups;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks TRIG"}        = $trigger_groups;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks SYNC"}        = $sync_groups;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks OPTIONS"}     = $options;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks TAGS"}        = $tags;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks BEFORE"}      = $before_list;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks AFTER"}       = $after_list;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks WRITES"}      = $writes_list;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks READS"}       = $reads_list;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks WHILE"}       = $while_list;
      $schedule_db{"\U$thorn\E BLOCK_$n_blocks IF"}          = $if_list;

      $buffer .= "\@BLOCK\@$n_blocks\n";
      $after_list =~ s/,\s*$//;
      my $all = qq{ ALL VARIABLES:
            name=$name, as=$as, type=$type, desc=$description, where=$where, lang=$language,
            mem=$mem_groups, comm=$comm_groups, trigger=$trigger_groups, sync=$sync_groups,
            opts=$options, tags=$tags, before=$before_list, after=$after_list,
            writes=$writes_list, reads=$reads_list, while=$while_list, if=$if_list}."\n";
      $all =~ s/,([\s]*,)*/,/g;
      $n_blocks++;
    }
    elsif($data[$line_number] =~ m/^\s*(STOR|COMM)[^:]*:\s*/i)
    {
      ($line_number, $type, $groups) = &ParseScheduleStatement($line_number, @data);
      $schedule_db{"\U$thorn\E STATEMENT_$n_statements TYPE"}        = $type;
      $schedule_db{"\U$thorn\E STATEMENT_$n_statements GROUPS"}      = $groups;
      $buffer .= "\@STATEMENT\@$n_statements\n";
      $n_statements++;
    }
    elsif($data[$line_number] =~ m/^\s*(STOR|COMM).*/i)
    {
      $hint = "Line should be of format STORAGE: <group>, <group>";
      $message = "Format error in STORAGE statement of $thorn\nLine is: $data[$line_number]";
      &CST_error(0,$message,$hint,__LINE__,__FILE__);
	
    }
    else
    {
      $buffer .= "$data[$line_number]\n";
    }
  }

  $schedule_db{"\U$thorn\E FILE"}         = $buffer;
  $schedule_db{"\U$thorn\E N_BLOCKS"}     = $n_blocks;
  $schedule_db{"\U$thorn\E N_STATEMENTS"} = $n_statements;
  
  $buffer1 = $buffer;

  return %schedule_db;
}

sub concat {
	my $a = shift;
	my $b = shift;
	if(!defined($a) or $a eq "") {
		return $b;
	} else {
		return $a.",".$b;
	}
}
sub get_all {
    my $ret = [];
    my $node = shift;
    my $tag = shift;
    return undef unless(defined($node));
	if(ref($node) eq "ARRAY") {
		for my $ch (@$node) {
        	my $r = get_all($ch,$tag);
        	for my $n (@$r) {
            	push @$ret, $n;
        	}
		}
		return $ret;
	}
    if($node->{name} eq $tag) {
        push @$ret, $node;
    }
    if(!defined($node->{children})) {
    	return $ret;
    }
    for my $ch (@{$node->{children}}) {
        my $r = get_all($ch,$tag);
        for my $n (@$r) {
            push @$ret, $n;
        }
    }
    return $ret;
}
sub get_all_text {
    my $node = shift;
    my $nm = $node->{name};
    if($nm eq "booleq") {
        # CCTK_Equals
        return $node->{children}->[0]->{text}."(".
            get_all_text($node->{children}->[1]).
            ",".
            get_all_text($node->{children}->[2]).
            ")";
    } elsif($nm eq "boolpar") {
        return "(".get_all_text($node->{children}->[0]).")";
    } elsif($nm eq "boolact") {
        return $node->{children}->[0]->{text}."(".
            get_all_text($node->{children}->[1]).
            ")";
    } elsif($nm eq "boolneg") {
        return "!".get_all_text($node->{children}->[0]);
    } elsif($nm eq "boolstar") {
        return "*".get_all_text($node->{children}->[0]);
    } elsif($nm =~ /^(name|quote|boolcmp|num|boolop)$/) {
        return $node->{text};
    } elsif($nm =~ /^(boolexpr|boolterm|string|term|vname)$/) {
        my $str = "";
        for my $child (@{$node->{children}}) {
            $str .= get_all_text($child);
        }
        return $str;
    } else {
        die "get_all_text($nm)";
    }
}
sub get_all_vnames_inner {
	my @r = ();
	my $root = shift;
	my $arr = get_all($root,"vname");
	for my $v (@$arr) {
		my $children = $v->{children};
		my $str = "";
		for(my $i=0;$i<=$#$children;$i++) {
			if($children->[$i]->{name} eq "name") {
				$str .= "::" if($i > 0);
				$str .= $children->[$i]->{text};
			} elsif($children->[$i]->{name} eq "num") {
				$str .= "[" . $children->[$i]->{text} . "]";
			} elsif($children->[$i]->{name} eq "expr") {
				$str .= "[" . $children->[$i]->{children}->[0]->{text} . "]";
			} else {
				carp "ELEM: ".$children->[$i]->{name};
                print "DIE\n";
                die "done";
			}
		}
		push @r, $str;
#		if($#$children == 0) {
#			push @r, $children->[0]->{text};
#		} else {
#			push @r, $children->[0]->{text}."::".$children->[1]->{text};
#		}
	}
	return \@r;
}
sub get_all_vnames {
	my @r = ();
	my $root = shift;
	return "" unless(defined($root));
	if(ref($root) eq "ARRAY") {
		for my $ch (@$root) {
			my $subr = get_all_vnames_inner($ch);
			push @r, @$subr;
		}
		return join(",",@r);
	} else {
		my $subr = get_all_vnames_inner($root);
		push @r, @$subr;
	}
	return join(",",@r);
}
sub get_one {
    my $node = shift;
    my $tag = shift;
    
    if(!defined($node->{children})) {
    	return undef;
    }
    
    for my $ch (@{$node->{children}}) {
    	if($ch->{name} eq $tag) {
    		return $ch;
    	}
    }
    for my $ch (@{$node->{children}}) {
        my $r = get_one($ch,$tag);
		if(defined($r)) {
			return $r;
		}
    }
    return undef;
}

sub unquote {
	my $str = shift;
	$str =~ s/^"//;
	$str =~ s/"$//;
	return $str;
}

sub parse_schedule_ccl2
{
  my($thorn, $file) = @_;
  my($line_number);
  my(%schedule_db);
  my($buffer);
  my($n_blocks);
  my($n_statements);
  my($groups);

  $buffer       = "";
  $n_blocks     = 0;
  $n_statements = 0;

  # Run Piraha, require the resulting grammar
  my $parse_tree;
  my $old = 0;
  if($old) {
    my $pm = $file;
    $pm =~ s/\.ccl$/.pm/;
    unlink($pm);
    system("gram --perl /home/sbrandt/cactus/schedule.peg $file");
    require $pm;
    $parse_tree = $VAR;
  } else {
    $parse_tree = incl("$schedules_dir/$thorn.pm");
  }

  $style2 = "";

  my %block_map = ();
  
  # Grammatical structure is
  # statements
  #   statement
  #     schedule|if|storage
  #my $scheds = get_all($VAR,"statement");
  do_schedule_tree($parse_tree,\$n_blocks,\$n_statements,\$buffer,\%schedule_db,$thorn);
  $buffer2 = $buffer;

  $schedule_db{"\U$thorn\E FILE"}         = $buffer;
  $schedule_db{"\U$thorn\E N_BLOCKS"}     = $n_blocks;
  $schedule_db{"\U$thorn\E N_STATEMENTS"} = $n_statements;
  
#  print "THORN: $thorn, NODE: ",Dumper($VAR),"\n";

  return %schedule_db;
}

#/*@@
#  @routine    ParseScheduleBlock
#  @date       Thu Sep 16 23:34:55 1999
#  @author     Tom Goodale
#  @desc
#  Parses a schedule block and extracts all the info.
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/
sub ParseScheduleBlock
{
  my($thorn,$line_number, @data) = @_;
  my($name, $as, $type, $description, $where, $language,
     $mem_groups, $comm_groups, $trigger_groups, $sync_groups,
     $options, $tags, $before_list, $after_list,
     $writes_list, $reads_list, $while_list, $if_list);
  my(@fields);
  my($field);
  my(@before_list)    = ();
  my(@after_list)     = ();
  my(@writes_list)    = ();
  my(@reads_list)     = ();
  my(@while_list)     = ();
  my(@if_list)        = ();
  my(@mem_groups)     = ();
  my(@comm_groups)    = ();
  my(@trigger_groups) = ();
  my(@sync_groups)    = ();
  my(@options)        = ();
  my(@tags)           = ();
  my($keyword) = "";
  my(@current_sched_list) = ();

  $where = "";
  $as    = "";

  #Parse the first line of the schedule block

  $data[$line_number] =~ m:^\s*(.*)\s*$:;

  @fields = split(/([\s,\(\)]+)/, $1);

  # Find the type of the block,
  if($fields[2] =~ m:^group$:i)
  {
    $type = "GROUP";
    $field = 4;
  }
  elsif($fields[1] =~ m:^function$:i)
  {
    $type = "FUNCTION";
    $field = 4;
  }
  else
  {
    $type = "FUNCTION";
    $field = 2;
  }

  $name = $fields[$field];
  $field ++;

  while($field <= $#fields)
  {
    if($fields[$field] =~ m:^\s*$:)
    {
      $field++;
      next;
    }

    if($fields[$field] =~ m:^AT$:i)
    {
      $field+=2;
      if($where ne "")
      {
        print STDERR "Error parsing schedule block line '$data[$line_number]'\n";
        print STDERR "Attempt to schedule same block at/in two places.\n";
      }
      else
      {
        if($fields[$field] =~ m:CCTK_:i)
        {
          $where = "\U$fields[$field]\E";
        }
        else
        {
          $where = "CCTK_\U$fields[$field]\E";
        }
      }

      # check that the given schedule bin is recognized
      if ($where !~ $schedule_bin_regexp)
      {
        &CST_error(0,"Schedule bin \'$where\' not recognised in schedule.ccl " .
                   "file of thorn $thorn","",__LINE__,__FILE__);
      }
      $field+=2;
    }
    elsif($fields[$field] =~ m:^IN$:i)
    {
      $field+=2;
      if($where ne "")
      {
        print STDERR "Error parsing schedule block line '$data[$line_number]'\n";
        print STDERR "Attempt to schedule same block at/in two places.\n";
      }
      else
      {
        $where = "$fields[$field]";
      }
      $field+=2;
    }
    elsif($fields[$field] =~ m:^AS$:i)
    {
      $field+=2;
      if($as ne "")
      {
        print STDERR "Error parsing schedule block line '$data[$line_number]'\n";
        print STDERR "Attempt to schedule same block with two names.\n";
      }
      else
      {
        $as = "$fields[$field]";
      }
      $field+=2;
    }
    elsif($fields[$field] =~ m:^BEFORE$:i)
    {
      if($keyword ne "")
      {
        &CST_error(0,"Error parsing schedule block line '$data[$line_number]'",
                   "",__LINE__,__FILE__);
      }
      $keyword = "BEFORE";
      $field++;
    }
    elsif($fields[$field] =~ m:^AFTER$:i)
    {
      if($keyword ne "")
      {
        &CST_error(0,"Error parsing schedule block line '$data[$line_number]'",
                   "",__LINE__,__FILE__);
      }
      $keyword = "AFTER";
      $field++;
    }
    elsif($fields[$field] =~ m:^WHILE$:i)
    {
      if($keyword ne "")
      {
        &CST_error(0,"Error parsing schedule block line '$data[$line_number]'",
                   "",__LINE__,__FILE__);
      }
      $keyword = "WHILE";
      $field++;
    }
    elsif($fields[$field] =~ m:^IF$:i)
    {
      if($keyword ne "")
      {
        &CST_error(0,"Error parsing schedule block line '$data[$line_number]'",
                   "",__LINE__,__FILE__);
      }
      $keyword = "IF";
      $field++;
    }
    elsif($keyword ne "" && $fields[$field] =~ m:\s*\(\s*:)
    {
      # Parse a clause of the form BEFORE(a,b,c)
      @current_sched_list = ();

      $field++;

      while($fields[$field] !~ m:\s*\)\s*: && $field <= $#fields)
      {
        if($fields[$field] =~ m:\s*,\s*:)
        {
          $field++;
          next;
        }

        push(@current_sched_list, $fields[$field]);
        $field++;
      }

      $field++;

      if($keyword eq "BEFORE")
      {
        push(@before_list, @current_sched_list);
      }
      elsif($keyword eq "AFTER")
      {
        push(@after_list, @current_sched_list);
      }
      elsif($keyword eq "WHILE")
      {
        push(@while_list, @current_sched_list);
      }
      elsif($keyword eq "IF")
      {
        die "DONE";
        push(@if_list, @current_sched_list);
      }

      # Reset keyword to empty for next time.
      $keyword = "";
    }
    elsif($keyword ne "" && $fields[$field] =~ m:\w:)
    {
      if($keyword eq "BEFORE")
      {
        push(@before_list, $fields[$field]);
      }
      elsif($keyword eq "AFTER")
      {
        push(@after_list, $fields[$field]);
      }
      elsif($keyword eq "WHILE")
      {
        push(@while_list, $fields[$field]);
      }
      elsif($keyword eq "IF")
      {
        #die "DONE ".Dumper(\@fields);
        push(@if_list, $fields[$field]);
      }
      $field++;
      $keyword = "";
    }
    elsif(($keyword eq "") && ($field == $#fields) && ($fields[$field] =~ m:\s*\{\s*:))
    {
      # This bit matches a { at the end of a line
      # I don't like it, but it seems to be already in use 8-(
      $line_number--;
      $keyword = "";
      last;
    }
    else
    {
      &CST_error(0,"Error parsing schedule block line '$data[$line_number]'",
                 "",__LINE__,__FILE__);
      $keyword = "";
      $field++;
    }
  }
  $line_number++;

  # If no alias is set, just use the name.
  if($as eq "")
  {
    $as = $name;
  }

  # Parse the rest of the block

  if($data[$line_number] !~ m:\s*\{\s*:)
  {
    &CST_error(0,"Error parsing schedule block line '$data[$line_number]'\nMissing { at start of block","",__LINE__,__FILE__);
    $line_number++ while($line_number<scalar(@data) and $data[$line_number] !~ m:\s*\}\s*:);
  }
  else
  {
    while($data[$line_number] !~ m:\s*\}\s*:)
    {
      $line_number++;
      if($data[$line_number] =~ m/^\s*STOR[^:]*:\s*(.*)$/i)
      { 
        if ($where eq "CCTK_STARTUP" )
        {
          &CST_error(1, "Scheduling storage \"$name\" at startup in thorn \"$thorn\"","Storage cannot be allocated at startup",__LINE__,__FILE__);
        }
        elsif ($where eq "CCTK_SHUTDOWN" )
        {
          &CST_error(1, "Scheduling storage \"$name\" at shutdown in thorn \"$thorn\"","Storage cannot be allocated at shutdown",__LINE__,__FILE__);
        }

        push(@mem_groups, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*COMM[^:]*:\s*(.*)$/i)
      {
        push(@comm_groups, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*TRIG[^:]*:\s*(.*)$/i)
      {
        push(@trigger_groups, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*SYNC[^:]*:\s*(.*)$/i)
      {
        push(@sync_groups, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*WRITES\s*:\s*(.*)$/i)
      {
        push(@writes_list, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*READS\s*:\s*(.*)$/i)
      {
        push(@reads_list, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*OPTI[^:]*:\s*(.*)$/i)
      {
        push(@options, split(/\s+|\s*,\s*/, $1));
      }
      elsif($data[$line_number] =~ m/^\s*TAGS[^:]*:\s*(.*)$/i)
      {
        push(@tags, $1);
      }
      elsif($data[$line_number] =~ m/^\s*LANG[^:]*:\s*(.*)$/i)
      {
        if($language ne "")
        {
          $thisline = $data[$line_number];
          $thisline =~ s/^\s*([^\s])\s$/$1/;
          $message  = "Error parsing schedule block in $thorn\n";
          $message .= "Attempt to specify language more than once\n";
          $message .= "Line: $thisline";
          &CST_error(0,$message,"",__LINE__,__FILE__);
        }
        else
        {
          $language= $1;
          if ($type eq "GROUP")
          {
            &CST_error(1, "Scheduling group \"$name\" with LANG specifier in thorn \"$thorn\"","Groups should not have a LANG specificier",__LINE__,__FILE__);
          }
        }
      }
      elsif($data[$line_number] =~ m:\s*\}\s*:)
      {
        # do nothing.
      }
      else
      {
	$data[$line_number] =~ /^(.*)\n+/;
        &CST_error(0,"Unrecognised statement in schedule block ($name) in schedule.ccl for thorn $thorn\n\"$1\"","",__LINE__,__FILE__);
      }
    }
  }
  if($data[$line_number] =~ m:\s*\}\s*\"([^\"]*)\":)
  {
    $description = $1;
  }
  else
  {
    $message = "Missing desciption at end of schedule block ($name) in schedule.ccl for thorn $thorn";
    &CST_error(0,$message,"",__LINE__,__FILE__);
  }

  # Turn the arrays into strings.
  $mem_groups     = join(",", @mem_groups);
  $comm_groups    = join(",", @comm_groups);
  $trigger_groups = join(",", @trigger_groups);
  $sync_groups    = join(",", @sync_groups);
  $options        = join(",", @options);
  $tags           = join(" ", @tags);
  $before_list    = join(",", @before_list);
  $after_list     = join(",", @after_list);
  $writes_list    = join(",", @writes_list);
  $reads_list     = join(",", @reads_list);
  $while_list     = join(",", @while_list);
  $if_list        = join(",", @if_list);


  return ($line_number,
          $name, $as, $type, $description, $where, $language,
          $mem_groups, $comm_groups, $trigger_groups, $sync_groups,
          $options, $tags, $before_list, $after_list,
          $writes_list, $reads_list, $while_list, $if_list);

}

#/*@@
#  @routine    ParseScheduleStatement
#  @date       Thu Sep 16 23:36:04 1999
#  @author     Tom Goodale
#  @desc
#  Extracts info from a simple schedule statement.
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/
sub ParseScheduleStatement
{
  my($line_number, @data) = @_;
  my($type, $groups);

  $data[$line_number] =~ m/^\s*(STOR|COMM)[^:]*:\s*(.*)/i;

  $type = "\U$1\E";

  $groups = $2;

  return ($line_number, $type, $groups);
}

#/*@@
#  @routine    PrintScheduleStatistics
#  @date       Sun Sep 19 13:07:08 1999
#  @author     Tom Goodale
#  @desc
#  Prints out statistics about a thorn's schedule.ccl
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/
sub PrintScheduleStatistics
{
  my($thorn, %schedule_database) = @_;

  print "          " . $schedule_database{"\U$thorn\E N_BLOCKS"} . " schedule blocks.\n";

  return;
}

#/*@@
#  @routine    check_schedule_database
#  @date       26th April 2002
#  @author     Gabrielle Allen
#  @desc
#  Checks on consistency of schedule database
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#@@*/

sub check_schedule_database
{
  my($rhschedule_db,%thorns) = @_;

  # make a list of all group names
  $allgroups = "";
  foreach $thorn (sort keys %thorns)
  {
    # Process each schedule block
    for($block = 0 ; $block < $rhschedule_db->{"\U$thorn\E N_BLOCKS"}; $block++)
    {
      if ($rhschedule_db->{"\U$thorn\E BLOCK_$block TYPE"} =~ /GROUP/)
      {
	$allgroups .= " $rhschedule_db->{\"\U$thorn\E BLOCK_$block NAME\"}";
      }
    }
  }

  # check that scheduling in is only for a known group
  foreach $thorn (sort keys %thorns)
  {
    # Process each schedule block
    for($block = 0 ; $block < $rhschedule_db->{"\U$thorn\E N_BLOCKS"}; $block++)
    {
      if ($allgroups !~ /$rhschedule_db->{"\U$thorn\E BLOCK_$block WHERE"}/)
      {
	if ($rhschedule_db->{"\U$thorn\E BLOCK_$block WHERE"} !~ $schedule_bin_regexp)
	{
	  $message = "Scheduling routine $rhschedule_db->{\"\U$thorn\E BLOCK_$block NAME\"} from thorn $thorn in non-existent group or timebin $rhschedule_db->{\"\U$thorn\E BLOCK_$block WHERE\"}";
	  $hint = "If this routine should be scheduled check the spelling of the group or timebin name. Note that scheduling IN must be used to schedule a routine to run in a thorn-defined schedule group, whereas scheduling AT is used for a usual timebin. (Schedule IN may also be used with the usual timebins, but in this case the full name of the bin must be used, e.g. CCTK_EVOL and not EVOL)";
	  &CST_error(1,$message,$hint,__LINE__,__FILE__);
	}
      }
    }
  }
}

sub do_schedule_tree {
	my $node = shift;
	my $n_blocks = shift;
	my $n_statements = shift;
	my $buffer = shift;
	my $schedule_db = shift;
	my $thorn = shift;
	
    if($node->{name} =~ /^annot:/) {
        ;
	} elsif($node->{name} eq "if") {
		$$buffer .= "if (";
		do_schedule_tree($node->{children}->[0],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		$$buffer .= ")\n";
		do_schedule_tree($node->{children}->[1],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		if(defined($node->{children}->[2])) {
			if($node->{children}->[2]->{name} eq "if") {
                # Parse an else-if
				$$buffer .= " else ";
				do_schedule_tree($node->{children}->[2],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
			} else {
                # Parse a terminal else
				$$buffer .= " else ";
				do_schedule_tree($node->{children}->[2],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
			}
		}
    } elsif($node->{name} eq "block") {
        $$buffer .= "{\n";
		for my $ch (@{$node->{children}}) {
			do_schedule_tree($ch,$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		}
        $$buffer .= "}\n";
	} elsif($node->{name} eq "schedule") {
		do_schedule($node,$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
	} elsif($node->{name} eq "storage") {
		my $groups = get_all_vnames($node);
#		$groups =~ s/,/ /g;
      	$schedule_db->{"\U$thorn\E STATEMENT_$$n_statements TYPE"}        = "STOR";
      	$schedule_db->{"\U$thorn\E STATEMENT_$$n_statements GROUPS"}      = $groups;
      	$$buffer .= "\@STATEMENT\@$$n_statements\n";
      	$$n_statements++;
	} elsif($node->{name} eq "boolneg") {
		$$buffer .=  "!";
		for my $ch (@{$node->{children}}) {
			do_schedule_tree($ch,$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		}
	} elsif($node->{name} eq "boolstar") {
		$$buffer .=  "*";
		for my $ch (@{$node->{children}}) {
			do_schedule_tree($ch,$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		}
	} elsif($node->{name} eq "boolpar") {
        $$buffer .= "(";
		do_schedule_tree($node->{children}->[0],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
        $$buffer .= ")";
	} elsif($node->{name} eq "booleq") {
		$$buffer .=  $node->{children}->[0]->{text};
		$$buffer .= "(";
		do_schedule_tree($node->{children}->[1],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		$$buffer .= ",";
		do_schedule_tree($node->{children}->[2],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		$$buffer .= ")";
	} elsif($node->{name} eq "boolact") { 
		$$buffer .=  $node->{children}->[0]->{text};
		$$buffer .= "(";
		do_schedule_tree($node->{children}->[1],$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		$$buffer .= ")";
	} elsif(defined($node->{text}) and $node->{name} ne "block" and $node->{name} ne "sched") {
		#print "TEXT:(",$node->{name},")=[",$node->{text},"]\n" if($node->{text} =~ /stress_energy_storage/);
		$$buffer .= $node->{text};
    } elsif($node->{name} eq "boolexpr") {
        $$buffer .= get_all_text($node);
	} elsif($node->{name} =~ /^(sched|statement)$/) {
		for my $ch (@{$node->{children}}) {
			do_schedule_tree($ch,$n_blocks,$n_statements,$buffer,$schedule_db,$thorn);
		}
	} else {
        die "UNK node => $node->{name}";
    }
}

sub do_schedule {
		my $node = shift;
		my $n_blocks = shift;
		my $n_statements = shift;
		my $buffer = shift;
		my $schedule_db = shift;
		my $thorn = shift;
        my ($line_number,
            $name, $as, $type, $description, $where, $language,
            $mem_groups, $comm_groups, $trigger_groups, $sync_groups,
            $options, $tags, $before_list, $after_list,
            $writes_list, $reads_list, $while_list, $if_list);
        $comm_groups = "";
        $after_list = "";
        $trigger_groups = "";
        $while_list = "";
        $if_list = "";
        $tags = "";
        $before_list = "";
        $mem_groups = "";
        $where = "";
        $block = $node->{children};
        my $block_name = "\@BLOCK\@$$n_blocks";

        # second child tells the name of the schedule item
        $name = $block->[1]->{text};
        
        # default value for "as"
        $as = $name;
        
        $block_map{$name} = $block_name;
        $block_map{$block_name} = $name;

        my $lang = get_one($node,"lang");
        if(defined($lang)) {
			$language = $lang->{children}->[0]->{text};	
        }
        
        $sync_groups = get_all_vnames(get_all($node,"sync"));
        $trigger_groups = get_all_vnames(get_all($node,"triggers"));
        $options = get_all_vnames(get_one($node,"options"));
        $reads_list = get_all_vnames(get_all($node,"reads"));
        $writes_list = get_all_vnames(get_all($node,"writes"));

        # first child node tells whether we're a group or not
        my $isgroup = $block->[0]->{name};
        if($isgroup eq "group") {
        	$type = "GROUP";
        } else {
        	$type = "FUNCTION";
        }
        
        $description = unquote($block->[-1]->{text});

        # the third child is the list of prepositions, e.g. as, at, before, after
        my $prepositions = $block->[2]->{children};
        for my $preposition (@$prepositions) {
           my $prep_name = "\U$preposition->{children}->[0]->{text}";

           # objects of the preposition are a list of vnames
           my $list = get_all_vnames($preposition->{children});
           if($prep_name eq "BEFORE") {
				$before_list = concat($before_list,$list);
           } elsif($prep_name eq "WHILE") {
				$while_list = $list;
           } elsif($prep_name eq "AT") {
           		$where = $list;
           		my $joined = join("|",@schedule_bins);
           		$where =~ s/\b(?:CCTK_|)($joined)\b/\UCCTK_$1/xi;
           } elsif($prep_name eq "IN") {
           		$where = $list;
           } elsif($prep_name eq "AS") {
           		$as = $list;
           } elsif($prep_name eq "AFTER") {
           		$after_list = concat($after_list,$list);
           } elsif($prep_name eq "IF") {
           		$if_list = $list;
           } else {
                die "Not handled: $prep_name";
           }
        }
        my $stores = get_all($node,"storage");
        for my $store (@$stores) {
        	my $groups = get_all_vnames($store);
#        	$groups =~ s/,/ /g;
#      		$schedule_db->{"\U$thorn\E STATEMENT_$$n_statements TYPE"}        = $type;
#      		$schedule_db->{"\U$thorn\E STATEMENT_$$n_statements GROUPS"}      = $groups;
#      		$$buffer .= "\@STATEMENT\@$$n_statements\n";
        	$mem_groups = concat($mem_groups,$groups);
#        	$$n_statements++;
        }
      	$$buffer .= $block_name . "\n";
        my $all = qq{ ALL VARIABLES:
            name=$name, as=$as, type=$type, desc=$description, where=$where, lang=$language,
            mem=$mem_groups, comm=$comm_groups, trigger=$trigger_groups, sync=$sync_groups,
            opts=$options, tags=$tags, before=$before_list, after=$after_list,
            writes=$writes_list, reads=$reads_list, while=$while_list, if=$if_list}."\n";
        $style2 .= $all;

      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks NAME"}        = $name;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks AS"}          = $as;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks TYPE"}        = $type;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks DESCRIPTION"} = $description;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks WHERE"}       = $where;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks LANG"}        = $language;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks STOR"}        = $mem_groups;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks COMM"}        = $comm_groups;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks TRIG"}        = $trigger_groups;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks SYNC"}        = $sync_groups;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks OPTIONS"}     = $options;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks TAGS"}        = $tags;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks BEFORE"}      = $before_list;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks AFTER"}       = $after_list;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks WRITES"}      = $writes_list;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks READS"}       = $reads_list;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks WHILE"}       = $while_list;
      	$schedule_db->{"\U$thorn\E BLOCK_$$n_blocks IF"}          = $if_list;
        $$n_blocks++;
}

1;

sub commas {
	my $str = shift;
    $str =~ s/[ \t]*'/'/g;
	$str =~ s/[ \t,]+/,/g;
	return $str;
}
sub clean_str {
	my $str = shift;
    $str =~ s{/\*.*?\*/}{}g; # remove C-style comments
    $str =~ s/\([ \t]*\(/((/g;
    $str =~ s/\)[ \t]*\)/))/g;
	$str =~ s/^[ \t]+//mg;
	$str =~ s/[ \t]+$//mg;
#	$str =~ s/[ \t,]+/,/mg;
	$str =~ s/ GROUPS' => '(.*)/" GROUPS' => '".commas($1)/ge;
	$str =~ s/ AFTER' => '(.*)/" AFTER' => '".commas($1)/ge;
	$str =~ s/ BEFORE' => '(.*)/" BEFORE' => '".commas($1)/ge;
	$str =~ s/ TRIG' => '(.*)/" TRIG' => '".commas($1)/ge;
	return $str;
}
sub die_compare {
	my $style1 = shift;
	my $style2 = shift;
	
	$style1 = clean_str($style1);
	$style2 = clean_str($style2);

	my $i1    = 0;
	my $i2    = 0;
	my $c1    = "";
	my $c2    = "";
	my $match = 1;
	my $ln1   = length($style1);
	my $ln2   = length($style2);
	my $out1 = "";
	my $out2 = "";
	if ( $style1 ne $style2 ) {
		while ( $i1 < $ln1 and $i2 < $ln2 ) {
			$c1 = substr( $style1, $i1, 1 );
			$c2 = substr( $style2, $i2, 1 );
			if ( $c1 eq $c2 ) {
				$i1++;
				$i2++;
				next;
			}
			if ( $c1 eq " " or $c1 eq "\t" or $c1 eq "\n" ) {
				$i1++;
				next;
			}
			if ( $c2 eq " " or $c2 eq "\t" or $c2 eq "\n") {
				$i2++;
				next;
			}
			if ( $c1 ne $c2 ) {
				#$style1 =~ s/.{$i1}/${&}xxx/s;
				#$style2 =~ s/.{$i2}/${&}yyy/s;
				$out1 = substr($style1,0,$i1)."xxx".substr($style1,$i1);
				$out2 = substr($style2,0,$i2)."yyy".substr($style2,$i2);
                my $fd1 = new FileHandle;
                my $fd2 = new FileHandle;
				$match = 0;
				last;
			}
		}
		unless ($match) {
            open($fd1,">out1.txt") or die;
            open($fd2,">out2.txt") or die;
            print $fd1 $out1;
            print $fd2 $out2;
            close($fd1);
            close($fd2);
			carp "i1=$i1 i2=$i2 c1=$c1 c2=$c2 ln1=$ln1 ln2=$ln2 OLD: $out1 NEW: $out2";
			die "done";
		} else {
			warn "COMPARE SUCCEEDED";
		}
	}
}

sub sort_dump {
	my $h = shift;
	my @k = sort keys %$h;
	my $str = "{\n";
	for my $k (@k) {
		$str .= "'$k' => '$h->{$k}'\n";
	}
	$str .= "}\n";
	return $str;
}

