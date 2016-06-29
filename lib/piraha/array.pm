package array;
use Data::Dumper;
use Carp;

sub getlen
{
  my $arrayRef = shift;
  return $#$arrayRef;
}

sub setlen
{
  my $arrayRef = shift;
  my $newlen = shift;
  return $#$arrayRef = $newlen;
}

sub append
{
  my $arrayRef = shift;
  confess("not an array") unless(ref($arrayRef) eq "ARRAY");
  my $value = shift;
  $arrayRef->[$#$arrayRef+1]=$value;
}

sub slice
{
  my $arrayRef = shift;
  my $lo = shift;
  my $hi = shift;
  my @a = @$arrayRef;
  $hi += $#a+1 if($hi < 0);
  my @a2 = @a[$lo .. $hi];
  return \@a2;
}

1;
