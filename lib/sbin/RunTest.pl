#!/bin/perl -s
#
# Test Suite tool

# For debugging:
my $debug = 0;
my $debug_indent_level = 0;
sub debug_print
{
  # debug statements are prefixed by a '#', to make them stand out from 
  # ordinary output
  $debug and print '#'.' 'x$debug_indent_level."@_\n";
}
sub debug
{
  $debug;
}
sub debug_indent
{
  $debug_indent_level++;
}
sub debug_dedent
{
  $debug_indent_level--;
}

use lib ".";
require "lib/sbin/RunTestUtils.pl";

use Data::Dumper;

# Read options from command line
$prompt = shift;   
$prompt =~ tr/A-Z/a-z/;
$home_dir = shift;
$config = shift;

&PrintHeader;

# Set up RunTest configuration
$config_data = &Configure($config,$home_dir,$prompt);

%runconfig = &InitialiseRunData();

# ----------------------------------------------------

# Sort out the static test data

# Initialise testdata database
$testdata = &InitialiseTestData();

# Find test parameter files
$testdata = &FindTestParameterFiles($testdata,$config_data);

# Parse test config files
$testdata = &ParseTestConfigs($testdata,$config_data,\%runconfig);

# Parse test parameter files
$testdata = &ParseAllParameterFiles($testdata,$config_data,\%runconfig);

# Print database
#&PrintDataBase($testdata);

# ----------------------------------------------------

$haverunall = 0;

while ($choice !~ /^Q/i)
{
  undef($thorn);
  undef($test);
  undef($choice);
  
  while (!($choice =~ /^Q/i) )
  {
      
    print "------------------------------------------------------------------------\n\n";
    print "  --- Menu ---\n\n";
    
    print "  Run entire set of tests [E]\n";
    print "  Run entire set of tests interactively [I]\n";
    print "  Choose test from [T]horn or [A]rrangement\n";
    print "  Rerun previous test [R]\n";
    print "  Rerun previous test and show run output on screen [S]\n";
    print "  Print tolerance table for data in previous test [P]\n";
    print "  Compare all files in the test output directories [O]\n";
    print "  Customize testsuite checking [C]\n";
    print "  Quit [Q]\n\n";

    if ($haverunall == 1)
    {
      $choice = &defprompt("  Select choice: ","Q");
    }
    else
    {
      $choice = &defprompt("  Select choice: ","E");
    }

    print "\n";
    
    if ($choice =~ /^[EIO]/i) 
    {
      print "  Processes: $config_data->{'NPROCS'}\n\n";

      # Reset/Initialise Test Statistics
      $rundata = &ResetTestStatistics($rundata,$testdata);

      # Run all parameter files
      # run up to nparallel tests in parallel
      my $nparallel = (defined ($ENV{'CCTK_TESTSUITE_PARALLEL_TESTS'}) ?
                       $ENV{'CCTK_TESTSUITE_PARALLEL_TESTS'} : 1);
      my %running_tests;
      my $wait_for_test = sub {
        # peel one finished test of the list of running tests
        my $finished_test = wait();
        my $retcode = $?;
        my ($thorn,$test,$STDOUT_CAPTURE,$STDERR_CAPTURE,$RESULTS_CAPTURE) = @{$running_tests{$finished_test}};
        delete $running_tests{$finished_test};

        # read in the test's stdout, stderr and results
        my $slurp = sub {
          my ($FN) = @_;
          local $/ = undef;
          open(my $FH, '<', $FN) or die "Could not open '$FN' for reading: $!";
          my $data = <$FH>;
          close $FH;
          #unlink $FN;
          return $data;
        };
        my ($TESTOUT, $TESTERR, $TESTRESULTS) =
          (&$slurp($STDOUT_CAPTURE), &$slurp($STDERR_CAPTURE), &$slurp($RESULTS_CAPTURE));
        # inject testdata values into global data structure
        my %testvalues = %{eval $TESTRESULTS};
        if(exists $testvalues{"NFAILED"}) {
          $testdata->{"NFAILED"} += $testvalues{"NFAILED"};
          $testdata->{"$thorn failed"} .= " ".$testvalues{"$thorn FAILED"};
        }
        if($retcode != 0) { # subprocess exited with an error
          $testdata->{"NFAILED"} += 1;
          $testdata->{"$thorn failed"} .= " ".$test;
        }
        foreach my $key (keys %testvalues) {
          if ($key =~ /^$thorn $test /) {
            $testdata->{$key} = $testvalues{$key};
          }
        }

        # handle and print output
	print "------------------------------------------------------------------------\n\n";
	print "  Test $thorn: $test \n";
	print "    \"$testdata->{\"$thorn $test DESC\"}\"\n";
        print STDOUT $TESTOUT;
        print STDERR $TESTERR;

        $rundata = &CompareTestFiles($test,$thorn,\%runconfig,$rundata,$config_data,$testdata);

	$rundata = &ReportOnTest($test,$thorn,$rundata,$testdata);
	if ($choice =~ /^I/i)
	{
	  &ViewResults($test,$thorn,\%runconfig,$rundata,$testdata);
	}
      };
      foreach $thorn (split(" ",$testdata->{"RUNNABLETHORNS"}))
      {
	foreach $test (split(" ",$testdata->{"$thorn RUNNABLE"}))
	{
          while(scalar keys %running_tests >= $nparallel) { # wait for a task to finish
            &$wait_for_test();
          }

	  print "  Starting test $thorn: $test \n" unless $nparallel == 1;
	  if ($choice !~ /^O/i)
	  {
            # TODO: replace these with pipes
            my $TMPFILE = "/tmp/$thorn.$test";
            my $STDOUT_CAPTURE = $TMPFILE.".stdout";
            my $STDERR_CAPTURE = $TMPFILE.".stderr";
            my $RESULTS_CAPTURE = $TMPFILE.".results";

            my $pid = fork(); # start a sub-process
            if(not $pid) {
              # the child process
              open(STDOUT, '>', $STDOUT_CAPTURE) or die "Could not open '$STDOUT_CAPTURE' for writing: $!";
              open(STDERR, '>', $STDERR_CAPTURE) or die "Could not open '$STDERR_CAPTURE' for writing: $!";;
              open(my $RESULTS, '>', $RESULTS_CAPTURE) or die "Could not open '$RESULTS_CAPTURE' for writing: $!";;

              $testdata = &RunTest("log",$test,$thorn,$config_data,$testdata);

              # get all values that need to be returned to our caller
              my %retvalues;
              foreach my $key (keys %$testdata) {
                if ($key =~ /^$thorn $test /) {
                  $retvalues{$key} = $testdata->{$key};
                }
              }
              # Deal with the error code
              if($retcode != 0) {
                $retvalues{"$thorn FAILED"} = $parfile;
                $retvalues{"NFAILED"} = 1;
              }
              $Data::Dumper::Terse = 1;
              print $RESULTS Dumper(\%retvalues) or die;
              close($RESULTS) or die;

              exit 0;
            } else {
              # the parent process
              $running_tests{$pid} = [$thorn,$test,$STDOUT_CAPTURE,$STDERR_CAPTURE,$RESULTS_CAPTURE];
            }
	  }

	}
      }
      while(scalar keys %running_tests > 0) { # wait for all tasks to finish
        &$wait_for_test();
      }

      # Write results of all tests
      &WriteFullResults($rundata,$testdata,$config_data);
      
      $haverunall = 1;

    } 
    elsif ($choice =~ /^[AT]/i)
    {
      ($ntests,@tests) = &ChooseTests($choice,$testdata);
      for ($i=0;$i<$ntests;$i++)
      {
	$test  = $tests[2*$i];
	$thorn = $tests[2*$i+1];
	print "------------------------------------------------------------------------\n\n";
	print "  Test $thorn: $test\n";
	print "    \"$testdata->{\"$thorn $test DESC\"}\"\n";
	$testdata = &RunTest("log",$tests[2*$i],$tests[2*$i+1],$config_data,$testdata);
	$rundata = &CompareTestFiles($tests[2*$i],$tests[2*$i+1],\%runconfig,$rundata,$config_data,$testdata);
	$rundata = &ReportOnTest($tests[2*$i],$tests[2*$i+1],$rundata,$testdata);
	&ViewResults($tests[2*$i],$tests[2*$i+1],\%runconfig,$rundata,$testdata);
      }
    }
    elsif ($choice =~ /^[RS]/i)
    {
      if ($thorn && $test)
      {
	print "------------------------------------------------------------------------\n\n";
	print "  Test $thorn: $test \n";
	print "    \"$testdata->{\"$thorn $test DESC\"}\"\n";
	if ($choice =~ /^S/i)
	{
	  $testdata = &RunTest("log stdout",$test,$thorn,$config_data,$testdata);
	}
	else
	{
	  $testdata = &RunTest("log",$test,$thorn,$config_data,$testdata);
	}
	$rundata = &CompareTestFiles($test,$thorn,\%runconfig,$rundata,$config_data,$testdata);
	$rundata = &ReportOnTest($test,$thorn,,$rundata,$testdata);
	&ViewResults($test,$thorn,\%runconfig,$rundata,$testdata);
      }
      else
      {
	print "  No previous test has been run\n";
      }
    }
    elsif ($choice =~ /^P/i)
    {
      if ($thorn && $test)
      {
        &PrintToleranceTable($test,$thorn,$testdata,\%runconfig);
      }
      else
      {
	print "  No previous test has been run\n";
      }
    }
    elsif ($choice =~ /^C/i)
    {
      print "  Options for customization\n";
      if ($test)
      {
	while ($choice !~ /^[AR]/i)
	{
	  print "    Change absolute tolerance for this run ($test) [A]\n";
	  print "    Change relative tolerance for this run ($test) [R]\n";
	  $choice = &defprompt("  Select choice: ","");
	  if ($choice =~ /A/i)
	  {
	    $runconfig{"$thorn $test ABSTOL"}{".*"} = &defprompt("  New absolute tolerance: ","$runconfig{\"$thorn $test ABSTOL\"}{\".*\"}");
	  }
	  elsif ($choice =~ /R/i)
	  {
	    $runconfig{"$thorn $test RELTOL"}{".*"} = &defprompt("  New relative tolerance: ","$runconfig{\"$thorn $test RELTOL\"}{\".*\"}");
	  }
	}
      }
      else
      {
	while ($choice !~ /^[AR]/i)
	{
	  print "    Change absolute tolerance from $runconfig{\"ABSTOL\"} for all further runs [A]\n";
	  print "    Change relative tolerance from $runconfig{\"RELTOL\"} for all further runs [R]\n";
	  $choice = &defprompt("  Select choice: ","");
	  if ($choice =~ /^A/i)
	  {
	    $runconfig{"ABSTOL"} = &defprompt("  New absolute tolerance: ","$runconfig{\"ABSTOL\"}");
	  }
	  elsif ($choice =~ /^R/i)
	  {
	    $runconfig{"RELTOL"} = &defprompt("  New relative tolerance: ","$runconfig{\"RELTOL\"}");
	  }
	}
      }
    }
    elsif ($choice =~ /^Q/i)
    {
#      $loop = 0;
    }
    else
    {
      print "  Choice not recognized, try again!\n";
    }
  }
  print "\n";
}
