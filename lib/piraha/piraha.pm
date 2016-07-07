use strict;
use array;

$main::indent=0;

sub parse_peg
{
  my $peg = shift;
  local $/ = undef;
  my $fd = new FileHandle;
  open($fd,$peg) or die "cannot open $peg";
  my $peg_contents = <$fd>;
  close($fd);
  my $g = new Grammar();
  my $rule = compileFile($g,$peg_contents);
  return ($g,$rule);
}

sub parse_src
{
  my $g = shift;
  local $/ = undef;
  my $rule = shift;
  my $src = shift;
  my $fd = new FileHandle;
  open($fd,$src) or die "cannot open $src";
  my $src_contents = <$fd>;
  close($fd);
  my $m = new Matcher($g,$rule,$src_contents);
  return $m;
}

sub parse
{
  my $peg = shift;
  my $src = shift;
  my ($g,$rule) = parse_peg($peg);
  return parse_src($g,$rule,$src);
}

sub applyChar
{
  my $prevChar = shift;
  my $currChar = shift;
  my $pat = shift;
  if(ref($pat) eq "Nothing" or ref($pat) eq "Fail") {
    return $pat;
  } elsif(ref($pat) eq "Literal") {
    if($currChar eq $pat->{c}) {
      return new Nothing();
    } else {
      return new Fail();
    }
  } elsif(ref($pat) eq "Seq") {
    my $npat = applyChar($prevChar,$currChar,$pat->{patternList}->[0]);
    #if(ref($npat) eq "Nothing") {
    #  $pat->{patternList} = array::slice($pat->{patternList},1,-1);
    #} elsif(ref($npat) eq "Fail") {
    #  return $npat;
    #} else {
    #  $pat->{patternList}->[0] = $npat;
    #}
    my $seq = new Seq();
    $seq->{patternList}->[0] = $npat;
    for(my $i=1;$i<=array::getlen($pat->{patternList});$i++) {
      $seq->{patternList}->[$i] = $pat->{patternList}->[$i];
    }
    return $seq;
  } elsif(ref($pat) eq "Or") {
    my $or = new Or();
    for(my $i=0;$i<=array::getlen($pat->{patterns});$i++) {
      my $p = $pat->{patterns}->[$i];
      $or->{patterns}->[$i] = applyChar($prevChar,$currChar,$p);
    }
    return $or;
  } else {
    confess("NoHandler[".ref($pat)."]");
  }
  return $pat;
}

# put in global space
sub canonicalize
{
  my $pat = shift;
  my $g = shift; # grammar
  my $upr;
  while(1) {
    if(ref($pat) eq "Lookup") {
      $pat = $g->{patterns}->{$pat->{name}};
      next;
    } elsif(ref($pat) eq "Seq") {
      my @pats = @{$pat->{patternList}};
      my $index = 0;
      #while($index <= $#pats and $pats[$index]->is_zero()) {
      #  if(ref($pats[$index]) eq "NegLookup") {
      #    $pats[$index]->{pat} = canonicalize($pats[$index]->{pat},$g);
      #  }
      #}
      if($#pats < 0) {
        return (new Nothing(),1);
      } elsif($#pats == 0) {
        # Sequence of 1
        $pat = $pats[0];
        next;
      } elsif($index > $#pats) {
        last;
      } elsif(ref($pats[$index]) eq "Fail") {
        return ($pats[$index],1);
      } elsif(ref($pats[$index]) eq "Nothing") {
        my $seq = new Seq();
        $seq->{patternList} = array::slice($pat->{patternList},$index+1,-1);
        $pat = $seq;
        next;
      } elsif(ref($pats[$index]) eq "Lookup") {
        # if elem[0] eq Lookup, expand
        #$pats[$index]->{patternList}->[$index] =
        return $g->{patterns}->{$pats[$index]->{name}};
        #next;
      } elsif(ref($pats[$index]) eq "Or") {
        # Absorb:
        # (A|B)C -> (AC|BC)
        my $or = new Or();
        # ((A|B)|C)D -> (A|B|C)D
        my ($ppp,$upr) = canonicalize($pats[0],$g);
        for my $p (@{$ppp->{patterns}}) 
        {
          my $seq = new Seq([]);
          array::append($seq->{patternList},$p);
          for(my $j=1;$j<=array::getlen($pat->{patternList});$j++) {
            my ($pp,$upr) = canonicalize($pat->{patternList}->[$j],$g);
            array::append($seq->{patternList},$pp);
          }
          array::append($or->{patterns},$seq);
        }
        $pat = $or;
        next;
      } elsif(ref($pats[$index]) eq "Literal") {
        last;
      } elsif(ref($pats[$index]) eq "Fail") {
        last;
      } elsif(ref($pats[$index]) eq "Nothing") {
        last;
      } elsif(ref($pats[$index]) eq "Seq") {
        my $seq = new Seq();
        my $n = 0;
        my $p0 = $pat->{patternList}->[0];
        for(my $i=0;$i<=array::getlen($p0->{patternList});$i++) {
          $seq->{patternList}->[$n++] = $p0->{patternList}->[$i];
        }
        for(my $i=1;$i<=array::getlen($pat->{patternList});$i++) {
          $seq->{patternList}->[$n++] = $pat->{patternList}->[$i];
        }
        $pat = $seq;
        next;
      } elsif(ref($pats[$index]) eq "Multi") {
        my $seq = new Seq();
        ($seq->{patternList}->[0],$upr) = canonicalize($pats[$index],$g);
        for(my $i=1;$i<=array::getlen($pat->{patternList});$i++) {
          $seq->{patternList}->[$i] = $pat->{patternList}->[$i];
        }
        $pat = $seq;
        next;
      }
      #} elsif($pats[$index]->possibly_zero()) {
      #  # put 0th item on z-list of seq
      #  die;
      confess("ref=[".ref($pats[$index])."]".(ref($pats[$index]) eq "Nothing")."!");
    } elsif(ref($pat) eq "Or") {
      my @pats = @{$pat->{patterns}};
      my @newpats = ();
      my $or = new Or();
      if($#pats < 0) {
        return (new Nothing(),1);
      } elsif($#pats == 0) {
        # Only option
        $pat = $pats[0];
        next;
      }
      # check all sub elements
      my $update = 0;
      if(!defined($pat->{canonical})) {
        $pat->{canonical}=1;
        $update=1;
      }
      for(my $i=0;$i<=$#pats;$i++) {
        if($i < $#pats and ref($pats[$i]) eq "Nothing") {
          # Truncate:
          # (A||B) -> (A|)
          $update = 1;
          $newpats[$#newpats+1] = $pats[$i];
          last;
        }
        if(ref($pats[$i]) eq "Or") {
          # cannonicalize i
          ($pats[$i],$upr) = canonicalize($pats[$i],$g);
          if(ref($pats[$i]) eq "Or") {
            # Flatten:
            # ((A|B)|C) -> (A|B|C)
            $update = 1;
            for my $p (@{$pats[$i]->{patterns}}) {
              $newpats[$#newpats+1]=$p;
            }
          } else {
            $newpats[$#newpats+1] = $pats[$i];
          }
        } elsif(ref($pats[$i]) eq "Fail") {
          $update = 1;
        } else {
          my $up;
          my ($newp,$up) = canonicalize($pats[$i],$g);
          $newpats[$#newpats+1] = $newp;
          $update = 1 if($up);
        }
      }
      if($update) {
        if($#newpats == 0) {
          $pat = $newpats[0];
        } else {
          #$pat->{patterns} = \@newpats;
          $or->{patterns} = \@newpats;
          $pat = $or;
          $pat->{canonical}=1;
        }
        next;
      }
    } elsif(ref($pat) eq "Multi") {
      my $p = $pat;
      if($p->{mx} == 0) {
        return new Fail();
      }
      my $seq = new Seq();
      $seq->{patternList}->[0] = $p->{pattern}; 
      my $lo = $p->{mn}-1;
      $lo = 0 if($lo < 0);
      $seq->{patternList}->[1] = new Multi($p->{pattern},$lo,$p->{mx}-1);
      my $or = new Or();
      $or->{patterns} = [$seq,new Nothing()];
      $pat = $or;
      next;
    }
    last;
  }
  return ($pat,0);
}

#***************************************
package Grammar;

sub new 
{
  my $class = shift;
  my $self = {
    patterns => {},
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Bracket;
use Carp;
use fmtc;

sub addRange
{
  my $self = shift;
  my $lo = shift;
  my $hi = shift;
  my $igcase = shift;
  if($igcase) {
    $self->addRange("\l$lo","\l$hi");
    $self->addRange("\u$lo","\u$hi");
    return;
  }
  my $a = $self->{ranges};
  my $r = [ord($lo), ord($hi)];
  confess "bad len lo=$lo" if(length($lo) != 1);
  confess "bad len hi=$hi" if(length($hi) != 1);
  confess "bad range" unless($r->[0] <= $r->[1]);
  $a->[1+$#$a] = $r;
  return $self;
}

sub match
{
  my $self = shift;
  my $m = shift;
  if($m->{textPos} >= length($m->{text})) {
    return 0;
  }
  my $rc = substr($m->{text},$m->{textPos},1);
  confess "zero c" if(length($rc)==0);
  my $c = ord($rc);
  for my $r (@{$self->{ranges}}) {
    if($r->[0] <= $c and $c <= $r->[1]) {
      if(!$self->{neg}) {
        #$m->{textPos}++;
        $m->inc_pos();
        return 1;
      } else {
        $m->fail($rc);
        return 0;
      }
    }
  }
  if(!$self->{neg}) {
    $m->fail($rc);
    return 0;
  } else {
    #$m->{textPos}++;
    $m->inc_pos();
    return 1;
  }
}

sub diag
{
  my $self = shift;
  my $out = "Bracket(";
  for my $r (@{$self->{ranges}}) {
    if($r->[0] eq $r->[1]) {
      $out .= fmt::fmtc(chr($r->[0]));
    } else {
      $out .= fmt::fmtc(chr($r->[0]))."-".fmt::fmtc(chr($r->[1]));
    }
  }
#  for my $r (@{$self->{ranges}}) {
#    if($r->[0] eq $r->[1]) {
#      $out .= ",".$r->[0];
#    } else {
#      $out .= ",".$r->[0]."-".$r->[1];
#    }
#  }
  $out .= ")";
  return $out;
}

sub new 
{
  my $class = shift;
  my $neg = shift;
  my @ranges = ();
  my $self = {
    neg => $neg,
    ranges => \@ranges,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Literal;
use Carp;
use fmtc;

sub possibly_zero
{
  return 0;
}

sub diag
{
  my $self = shift;
  return "Literal(".$self->{c}.")";
}

sub match
{
  my $self = shift;
  my $m = shift;
  if($m->{textPos} >= length($m->{text})) {
    return 0;
  }
  my $c = substr($m->{text},$m->{textPos},1);
  confess "zero c" if(length($c)==0);
  if($c eq $self->{c}) {
    #$m->{textPos}++;
    $m->inc_pos();
    return 1;
  } else {
    $m->fail($c);
    return 0;
  }
}

sub new 
{
  my $class = shift;
  my $c = shift;
  confess "bad literal '$c'" if(length($c) != 1);
  #confess if($c eq "a");
  my $self = {
    c => $c,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package ILiteral;
use Carp;
use fmtc;

sub match
{
  my $self = shift;
  my $m = shift;
  if($m->{textPos} >= length($m->{text})) {
    return 0;
  }
  my $c = substr($m->{text},$m->{textPos},1);
  confess "zero c" if(length($c)==0);
  if($c eq $self->{lc} or $c eq $self->{uc}) {
    #$m->{textPos}++;
    $m->inc_pos();
    return 1;
  } else {
    $m->fail($c);
    return 0;
  }
}

sub diag
{
  my $self = shift;
  if($self->{uc} eq $self->{lc}) {
    return "ILiteral(".$self->{uc}.")";
  } else {
    return "ILiteral(".$self->{lc}.",".$self->{uc}.")";
  }
}

sub new 
{
  my $class = shift;
  my $c = shift;
  confess "bad literal '$c'" if(length($c) != 1);
  my $self = {
    lc => "\L$c",
    uc => "\U$c",
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Seq;
use Carp;

sub possibly_zero
{
  my $self = shift;
  for my $pat (@{$self->{patternList}}) {
    if(!$pat->possibly_zero()) {
      return 1;
    }
  }
  return 0;
}

sub match
{
  my $self = shift;
  my $m = shift;
  for my $pat (@{$self->{patternList}}) {
    if(!$pat->match($m)) {
      return 0;
    }
  }
  return 1;
}

sub diag
{
  my $self = shift;
  my $out = "Seq{";
  my $tw = "";
  for my $p (@{$self->{patternList}}) {
    if(!defined($p)) {
      $out .= $tw . "UNDEF";
    } elsif($p == 0) {
      $out .= $tw . "ZERO";
    } else {
      $out .= $tw . $p->diag();
    }
    $tw = ",";
  }
  $out .= "}";
  #$out .= "size=(".array::getlen($self->{patternList}).")";
  return $out;
}

sub new 
{
  my $class = shift;
  my $patterns = \@_;
  my $ignCase = 0;
  my $igcShow = 0;
  if(ref($_[0]) eq "ARRAY") {
    $patterns = $_[0];
    $ignCase = $_[1];
    $igcShow = $_[2];
  }
  my $self = {
    patternList => $patterns,
    ignCase => $ignCase,
    igcShow => $igcShow,
  };
  my $pstr = "new Seq:";
  my $tw = "";
  for my $pat (@$patterns) {
    $pstr .= $tw.$pat->diag();
    $tw = ",";
  }
  $self->{pstr} = $pstr;
  #confess("empty seq") if(array::getlen($patterns)<0);
  bless $self, $class;
  return $self;
}
#***************************************
package Or;
use Carp;
use Data::Dumper;

sub possibly_zero
{
  my $self = shift;
  for my $pat (@{$self->{patterns}}) {
    if($pat->possibly_zero()) {
      return 1;
    }
  }
  return 0;
}

sub diag
{
  my $self = shift;
  my $out = "Or(";
  my $tw = "";
  for my $p (@{$self->{patterns}}) {
    $out .= $tw . $p->diag();
    $tw = ",";
  }
  $out .= ")";
  return $out;
}

sub match
{
  my $self = shift;
  my $m = shift;
  my $save = $m->{textPos};
  my $nchildren = array::getlen($m->{gr}->{children});
  for my $pat (@{$self->{patterns}}) {
    $m->{textPos} = $save;
    array::setlen($m->{gr}->{children},$nchildren);
    if($pat->match($m)) {
      return 1;
    }
  }
  return 0;
}

sub new 
{
  my $class = shift;
  my $ignCase = 0;
  my $igcShow = 0;
  my $patterns = [];
  if($#_==1 and !ref($_[0])) {
    $ignCase = $_[0];
    $igcShow = $_[1];
  } else {
    $patterns = \@_;
  }
  my $self = {
    patterns => $patterns,
    ignCase => $ignCase,
    igcShow => $igcShow,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Lookup;
use Carp;
use array;

sub possibly_zero
{
  return 0;
}

sub diag
{
  my $self = shift;
  return "Lookup(".$self->{name}.")";
}

sub match
{
  my $self = shift;
  my $m = shift;
  my $g = $m->{g}; # grammar;
  my $pname = $self->{name};
  my $pat = $g->{patterns}->{$pname};
  confess "no such pattern '$pname'" unless(defined($pat));
  my $chSave = $m->{gr};
  my $start = $m->{textPos};
  my $cap = $self->{capture};
  if($cap) {
  $m->{gr} = new Group($pname,$chSave->{text},$start,-1);
  }
  my $b = $pat->match($m);
  if($b) {
    if($cap) {
      $m->{gr}->{end} = $m->{textPos};
      #confess "empty literal" if($self->{name}="literal" and $m->{gr}->{start} == $m->{gr}->{end});
      array::append($chSave->{children},$m->{gr});
    }
  }
  if($cap) {
  $m->{gr} = $chSave;
  }
  return $b;
}

sub new
{
  my $class = shift;
  my $name = shift;
  my $capture = 1;
  $capture = 0 if($name =~ s/^-//);
  my $self = {
    capture => $capture,
    name => $name,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Nothing;

sub match
{
  return 1;
}

sub diag
{
  return "Nothing()";
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Fail;

sub match
{
  return 0;
}

sub diag
{
  return "Fail()";
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Start;

sub match
{
  my $self = shift;
  my $m = shift;
  return $m->{textPos}==0;
}

sub diag
{
  return "Start()";
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package End;

sub match
{
  my $self = shift;
  my $m = shift;
  return $m->{textPos}==length($m->{text});
}

sub diag {
  return "End()";
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Boundary;

sub match
{
  my $self = shift;
  my $m = shift;
  return 1 if($m->{textPos}==length($m->{text}) or $m->{textPos}==0);
  my $bf = substr($m->{text},$m->{textPos}-1,1);
  my $af = substr($m->{text},$m->{textPos},1);
  return 0 if($bf =~ /\w/ and $af =~ /\w/);
  return 1;
}

sub diag {
  return "Boundary()";
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Dot;
use Carp;

sub diag
{
  return "Dot()";
}

sub match
{
  my $self = shift;
  my $m = shift;
  if($m->{textPos} >= length($m->{text})) {
    return 0;
  }
  my $c = substr($m->{text},$m->{textPos},1);
  confess "zero c" if(length($c)==0);
  if($c =~ /./) {
    #$m->{textPos}++;
    $m->inc_pos();
    return 1;
  } else {
    return 0;
  }
}

sub new
{
  my $class = shift;
  my $self = {
  };
  bless $self, $class;
  return $self;
}
#***************************************
package NegLookAhead;

sub diag
{
  my $self = shift;
  return "NegLookAhead(".$self->{pat}->diag().")";
}

sub match
{
  my $self = shift;
  my $m = shift;
  my $p = $m->{textPos};
  my $b = $self->{pat}->match($m);
  $m->{textPos}=$p;
  return !$b;
}

sub new
{
  my $class = shift;
  my $pat = shift;
  my $ignc = shift;
  my $gram = shift;
  my $self = {
    pat => $pat,
    ignCase => $ignc,
    gram => $gram,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Multi;
use Carp;

sub match
{
  my $self = shift;
  my $m = shift;
  for(my $i=0;$i < $self->{mx};$i++) {
    my $save = $m->{textPos};
    my $nchildren = array::getlen($m->{gr}->{children});
    if(!$self->{pattern}->match($m) or $m->{textPos}==$save) {
      $m->{textPos}=$save;
      array::setlen($m->{gr}->{children},$nchildren);
      my $rc = $i >= $self->{mn};
      return $rc;
    }
  }
  return 1;
}

sub diag
{
  my $self = shift;
  if(!defined($self->{pattern})) {
    confess("bad pat");
  }
  return "Multi(".$self->{mn}.",".$self->{mx}.",".$self->{pattern}->diag().")";
}

sub new
{
  my $class = shift;
  my $pat = shift;
  my $mn = shift;
  my $mx = shift;
  if(!defined($mx)) {
    $mx = $mn;
    $mn = $pat;
    $pat = undef;
  }
  my $self = {
    pattern => $pat,
    mn  => $mn,
    mx  => $mx,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Group;
use Carp;

sub group
{
  my $self = shift;
  my $n = shift;
  return $self->{children}->[$n];
}

sub groupCount
{
  my $self = shift;
  my $n = shift;
  return array::getlen($self->{children})+1;
}

sub substring 
{
  my $self = shift;
  return substr($self->{text},$self->{start},$self->{end}-$self->{start});
}

sub mkstring
{
  my $self = shift;
  confess("bad self") unless(defined($self->{children}) and ref($self->{children}) eq "ARRAY");
  if($#{$self->{children}} < 0) {
    return $self->substring();
  } else {
    my $buf = "";
    for my $child (@{$self->{children}}) {
      $buf .= " " unless($buf eq "");
      $buf .= $child->mkstring();
    }
    return $buf;
  }
}

sub esc
{
  my $str = shift;
  $str =~ s/[\\"]/\\$&/g;
  $str =~ s/\n/\\n/g;
  $str =~ s/\t/\\t/g;
  $str =~ s/\r/\\r/g;
  return $str;
}

sub dump
{
  my $self = shift;
  my $post = shift;
  my $pre = "\n".("  " x $main::indent);
  $main::indent++;
  my $end = "\n".("  " x $main::indent);
  if(array::getlen($self->{children}) == -1) {
    $main::indent--;
    return $self->{name}."(\"".esc($self->substring())."\")";
  } else {
    my $out = $self->{name}.$pre."(".$end;
    my $tween = "";
    #for my $child (@{$self->{children}}) {
    my $ln = array::getlen($self->{children});
    for(my $i=0;$i<=$ln;$i++) {
      my $child = $self->{children}->[$i];
      $out .= $tween;
      $out .= $child->dump($i<$ln);
      $tween=",".$end;
    }
    $out .= $pre unless($post);
    $main::indent--;
    $out .= "\n".("  " x $main::indent) if($post);
    $out .= ")";
    #$out .= $pre unless($post);
    return $out;
  }
}

sub getPatternName
{
  my $self = shift;
  return $self->{name};
}

sub new
{
  my $class = shift;
  my $name = shift;
  my $text = shift;
  my $start = shift;
  my $end = shift;
  my $self = {
    children => [],
    name     => $name,
    text     => $text,
    start    => $start,
    end      => $end,
  };
  bless $self, $class;
  return $self;
}
#***************************************
package Matcher;
use Carp;

sub upos
{
  my $self = shift;
  my $pos = shift;
  $self->{textPos} = $pos;
  $self->{maxTextPos} = $pos if($pos > $self->{maxTextPos});
}

sub inc_pos
{
  my $self = shift;
  my $pos = ++$self->{textPos};
  $self->{maxTextPos} = $pos if($pos > $self->{maxTextPos});
}

sub matches
{
  my $self = shift;
  confess("no pat") unless(defined($self->{pat}));
  my $ret = $self->{pat}->match($self);
  return $ret;
}

sub groupCount
{
  my $self = shift;
  return $self->{gr}->groupCount();
}

sub group
{
  my $self = shift;
  my $i = shift;
  return $self->{gr}->group($i);
}

sub showError
{
  my $self = shift;
  return $self->{gr}->dump();
}

sub fail
{
  my $self = shift;
  my $c = shift;
  if($self->{textPos} > $self->{maxTextPos}) {
    $self->{maxTextPos} = $self->{textPos};
    $self->{hash} = {$c=>1};
  } elsif($self->{textPos} > $self->{maxTextPos}) {
    $self->{hash}->{$c} = 1;
  }
}

sub new
{
  my $class = shift;
  my $grammar = shift;
  my $pname = shift;
  my $text = shift;
  my $self = {
    text => $text,
    textPos => 0,
    maxTextPos => 0,
    pat => $grammar->{patterns}->{$pname},
    g => $grammar,
    gr => new Group($pname,$text,0,length($text)),
  };
  bless $self, $class;
  return $self;
}
#***************************************
1;
