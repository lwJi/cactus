package fmt;
use Carp;

sub fmtc
{
  my $c = shift;
  confess("bad strlen") unless(length($c)==1);
  return "{space}" if($c eq " ");
  return "{newline}" if($c eq "\n");
  return "{tab}" if($c eq "\t");
  return "{return}" if($c eq "\r");
  return $c;
}
1;
