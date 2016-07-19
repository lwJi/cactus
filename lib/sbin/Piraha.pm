package piraha;
use strict;
##############################################################################
# A minimal Piraha script loos like this:
# +---------------------------------------------------------------------------
# | use Piraha;
# |
# | die "usage: gram.pl peg_file src_file" unless($#ARGV==1);
# |
# | my ($peg_file, $src_file) = @ARGV;
# |
# | # Parse the patter (peg) file to create the grammar
# | # and the rule to start matching with (the last in the file).
# | my ($g,$rule) = piraha::parse_peg_file($peg_file);
# |
# | # Create a matcher from a grammar, a starting rule,
# | # and a source file.
# | my $matcher   = piraha::parse_src($g,$rule,$src_file);
# |
# | # Attempt the match
# | if($matcher->matches()) {
# |   # if successful dump a parse tree
# |   # the parse tree is in $matcher->{gr}
# |   print $matcher->{gr}->dump(),"\n";
# | } else {
# |   # if not successful, describe the failure
# |   $matcher->showError();
# | }
# +---------------------------------------------------------------------------
# 
# If a match is successful, the parse tree is stored in a data
# structure called a group. Properties of the groups:
# Group: $g
#
# $g->{name}
#   The name of the node in the parse tree this group
#   represents, i.e. the name of the rule in the grammar file.
#
# Fields:
# =======
# $g->{children}
#   A reference to an array of child Group objects.
#
# $g->{text}
#   The text string that was matched.
#
# $g->{start}
#   The start position of the match in the text file.
#
# $g->{end}
#   The end position of the match in the text file.
#
# Methods:
# ========
# $g->groupCount()
#   Returns the number of child groups.
#
# $g->substring()
#   Returns the portion of the string matched by
#   the group rule (i.e. the text from start to end).
#
# $g->mkstring($tween)
#   Similar to substring(). This method concatenates
#   all child elements that have no children themselves
#
# $g->has($num,$name)
#   Returns true if $num is less than groupCount(). If
#   $name is supplied, and child number $num does not
#   have name $name, then this method returns false.
#
# $g->group($num,$name)
#   Returns child group number $num. If no such child
#   exists, or if $name is supplied and does not match
#   the child name, then die.
#
# $g->is($name)
#   Returns true if the name of the current Group is
#   equal to $name. The equivalent of ($g->{name} eq $name).
#
# $g->dump()
#   Create a string representation of the parse tree.
#   This is useful for debugging.
##############################################################################

my $max_int = 2147483647;

use Carp;

sub getChar
{
    my $gr = shift;
    if($gr->groupCount()==1) {
        my $sub = gr->group(0)->substring();
        my $n = 0;
        for(my $i=0;$i<length($sub);$i++) {
            my $c = substr($sub,$i,1);
            if(ord($c) >= ord('0') && ord($c) <= ord('9')) {
                $n = $n*16+ord($c)-'0';
            } elsif(ord($c) >= ord('a') && ord($c) <= ord('f')) {
                $n = $n*16+ord($c)-ord('a')+10;
            } elsif(ord($c) >= ord('A') && ord($c) <= ord('F')) {
                $n = $n*16+ord($c)-ord('A')+10;
            }
        }
    }
    my $gs = $gr->substring();
    if(length($gs)==2) {
        my $c = substr($gs,1,1);
        if($c eq 'n') {
            return "\n";
        } elsif($c eq 'r') {
            return "\r";
        } elsif($c eq 't') {
            return "\t";
        } elsif($c eq 'b') {
            return "\b";
        } else {
            return $c;
        }
    } else {
        return substr($gs,0,1);
    }
}
sub mkMulti
{
    my $g = shift;
    if($g->groupCount()==0) {
        my $s = $g->substring();
        if("*" eq $s) {
            return new Multi(0,$max_int);
        } elsif("+" eq $s) {
            return new Multi(1,$max_int);
        } elsif("?" eq $s) {
            return new Multi(0,1);
        }
    } elsif($g->groupCount()==1) {
        my $mn = 1*($g->group(0)->substring());
        return new Multi($mn,$mn);
    } elsif($g->groupCount()==2) {
        my $mn = 1*($g->group(0)->substring());
        if($g->group(1)->groupCount()>0) {
            my $mx = 1*($g->group(1)->group(0)->substring());
            return new Multi($mn,$mx);
        } else {
            return new Multi($mn,$max_int);
        }
    }
}


sub compileFile
{
  my $g = shift;
  my $buffer = shift;
	my $grammar = fileparserGenerator();
	my $m = new Matcher($grammar,"file",$buffer);
	my $b = $m->matches();
  if(!$b) {
    confess("match failed ".$m->showError());
  }

	for(my $i=0;$i<$m->groupCount();$i++) {
		my $rule = $m->group($i);
		my $ptmp = compile($rule->group(1), 0, $grammar);
    my $nm = $rule->group(0)->substring();
		$g->{patterns}->{$nm} = $ptmp;
    $g->{default_rule} = $nm;
	}
  return $g->{default_rule};
}

sub compilePattern
{
  my $pattern = shift;
  my $grammar = reparserGenerator();
  my $m = new Matcher($grammar,"pattern",$pattern);
  if($m->matches()) {
    return compile($m->{gr},0,$grammar);
  }
}

sub compile
{
    my $g = shift;
    my $ignCase = shift;
    my $gram = shift;
    confess("missing g") unless(defined($g));
    my $pn = $g->getPatternName();
    if("literal" eq $pn) {
        my $c = getChar($g);
        if($ignCase) {
            return new ILiteral($c);
        } else {
            return new Literal($c);
        }
    } elsif("pattern" eq $pn) {
        if($g->groupCount()==0) {
            return new Nothing();
        }
        return compile($g->group(0),$ignCase,$gram);
    } elsif("pelem" eq $pn) {
        if($g->groupCount()==2) {
            my $pm = mkMulti($g->group(1));
            my $m = $pm; # Not sure
            $m->{pattern} = compile($g->group(0),$ignCase,$gram);
            return $pm;
        }
        return compile($g->group(0),$ignCase,$gram);
    } elsif("pelems" eq $pn or "pelems_top" eq $pn or "pelems_next" eq $pn) {
        my @li = ();
        for(my $i=0;$i<$g->groupCount();$i++) {
            my $pat = compile($g->group($i),$ignCase,$gram);
            push @li, $pat;
        }
        if(1+$#li==1) {
            return $li[0];
        }
        if($#li < 0) {
          print $g->dump(),"\n";
          confess("empty seq");
        }
        return new Seq(\@li,0,0);
    } elsif("group_inside" eq $pn or "group_top" eq $pn) {
        if($g->groupCount()==1) {
            return compile($g->group(0),$ignCase,$gram);
        }
        my @li = ();
        for(my $i=0;$i<$g->groupCount();$i++) {
            push @li, compile($g->group($i),$ignCase,$gram);
        }
        my $or_ = new Or(0,0);
        $or_->{patterns} = \@li;
        my $orp = $or_;
        return $orp;
    } elsif("group" eq $pn) {
        my $or_ = new Or(0,0);
        my $orp_ = $or_;
        my $ignC = $ignCase;
        my $inside = undef;
        if($g->groupCount()==2) {
            $ignC = $or_->{igcShow} = 1;
            my $ps = $g->group(0)->getPatternName();
            if($ps eq "ign_on") {
                $ignC = $or_->{ignCase} = 1;
            } elsif($ps eq "ign_off") {
                $ignC = $or_->{ignCase} = 0;
            } elsif($ps eq "neglookahead") {
                return new NegLookAhead(compile($g->group(1),$ignCase,$gram));
            } elsif($ps eq "lookahead") {
                return new LookAhead(compile($g->group(1),$ignCase,$gram));
            }
            $inside = $g->group(1);
        } else {
            $inside = $g->group(0);
        }
        for(my $i=0;$i<$inside->groupCount();$i++) {
            array::append($or_->{patterns},compile($inside->group($i),$ignC,$gram));
        }
        if($or_->{igcShow} == 0 and 1+array::getlen($or_->{patterns})==1) {
            return $or_->{patterns}->[0];
        }
        confess("empty or") if(array::getlen($orp_->{patterns})<0);
        return $orp_;
    } elsif("start" eq $pn) {
        return new Start();
    } elsif("end" eq $pn) {
        return new End();
    } elsif("boundary" eq $pn) {
        return new Boundary();
    } elsif("charclass" eq $pn) {
        my $br = new Bracket();
        my $brp = $br;
        my $i=0;
        if($g->groupCount()>0 and $g->group(0)->getPatternName() eq "neg") {
            $i++;
            $br->{neg} = 1;
        }
        for(;$i < $g->groupCount();$i++) {
            my $gn = $g->group($i)->getPatternName();
            if("range" eq $gn) {
                my $c0 = getChar($g->group($i)->group(0));
                my $c1 = getChar($g->group($i)->group(1));
                $br->addRange($c0, $c1, $ignCase);
            } else {
                my $c = getChar($g->group($i));
                $br->addRange($c,$c, $ignCase);
            }
        }
        return $brp;
    } elsif("named" eq $pn) {
        my $lookup = $g->group(0)->substring();
        if("brk" eq $lookup) {
            return new Break();
        }
        return new Lookup($lookup, $gram);
    } elsif("nothing" eq $pn) {
        return new Nothing();
    } elsif("s" eq $pn||"s0" eq $pn) {
        return new Lookup("-skipper", $gram);
    } elsif("dot" eq $pn) {
        return new Dot();
    } elsif("backref" eq $pn) {
        return new BackRef(ord(substr($g->substring(),1,1))-'0', $ignCase);
    }
    return undef;
}

use strict;

sub reparserGenerator() {
  my $g = new Grammar();
  $g->{patterns}->{"boundary"}=(new Seq(
    new Literal("\\"),
    new Literal('b')));
  $g->{patterns}->{"backref"}=(new Seq(
    new Literal("\\"),
    (new Bracket(0))
      ->addRange('1','9')
      ));
  $g->{patterns}->{"named"}=(new Seq(
    new Literal('{'),
    new Lookup("name",$g),
    new Literal('}')));
  $g->{patterns}->{"echar"}=(new Literal('-'));
  $g->{patterns}->{"num"}=(new Multi((new Bracket(0))
    ->addRange('0','9')
    ,1,2147483647));
  $g->{patterns}->{"dot"}=(new Literal('.'));
  $g->{patterns}->{"pattern"}=(new Seq(
    new Start(),
    new Or(
      new Lookup("group_inside",$g),
      new Nothing()),
    new End()));
  $g->{patterns}->{"range"}=(new Seq(
    new Lookup("cchar",$g),
    new Literal('-'),
    new Lookup("cchar",$g)));
  $g->{patterns}->{"literal"}=(new Or(
    new Seq(
      new Literal("\\"),
      new Literal('u'),
      new Lookup("hex",$g)),
    new Seq(
      new Literal("\\"),
      (new Bracket(1))
        ->addRange('b','b')
        ),
    (new Bracket(1))
      ->addRange('$','$')
      ->addRange('(','+')
      ->addRange('.','.')
      ->addRange('?','?')
      ->addRange('[','^')
      ->addRange('{','}')
      ));
  $g->{patterns}->{"neg"}=(new Literal('^'));
  $g->{patterns}->{"cchar"}=(new Or(
    new Seq(
      new Literal("\\"),
      new Literal('u'),
      new Lookup("hex",$g)),
    new Seq(
      new Literal("\\"),
      (new Bracket(1))
        ),
    (new Bracket(1))
      ->addRange('-','-')
      ->addRange("\\",']')
      ));
  $g->{patterns}->{"hex"}=(new Multi((new Bracket(0))
    ->addRange('0','9')
    ->addRange('A','F')
    ->addRange('a','f')
    ,4,4));
  $g->{patterns}->{"pipe"}=(new Nothing());
  $g->{patterns}->{"end"}=(new Literal('$'));
  $g->{patterns}->{"group"}=(new Seq(
    new Literal('('),
    new Or(
      new Lookup("ign_on",$g),
      new Lookup("ign_off",$g),
      new Lookup("lookahead",$g),
      new Lookup("neglookahead",$g),
      new Nothing()),
    new Or(
      new Lookup("group_inside",$g),
      new Nothing()),
    new Literal(')')));
  $g->{patterns}->{"ign_on"}=(new Seq(
    new Literal('?'),
    new Literal('i'),
    new Literal(':')));
  $g->{patterns}->{"pelem"}=(new Or(
    new Seq(
      new Or(
        new Lookup("named",$g),
        new Lookup("dot",$g),
        new Lookup("backref",$g),
        new Lookup("literal",$g),
        new Lookup("charclass",$g),
        new Lookup("group",$g)),
      new Or(
        new Lookup("quant",$g),
        new Nothing())),
    new Or(
      new Lookup("start",$g),
      new Lookup("end",$g),
      new Lookup("boundary",$g))));
  $g->{patterns}->{"nothing"}=(new Nothing());
  $g->{patterns}->{"group_inside"}=(new Seq(
    new Lookup("pelems",$g),
    new Multi(new Seq(
      new Literal('|'),
      new Lookup("pelems",$g)),0,2147483647),
    new Or(
      new Seq(
        new Lookup("nothing",$g),
        new Literal('|')),
      new Nothing())));
  $g->{patterns}->{"start"}=(new Literal('^'));
  $g->{patterns}->{"quantmax"}=(new Seq(
    new Literal(','),
    new Multi(new Lookup("num",$g),0,1)));
  $g->{patterns}->{"ign_off"}=(new Seq(
    new Literal('?'),
    new Literal('-'),
    new Literal('i'),
    new Literal(':')));
  $g->{patterns}->{"quant"}=(new Or(
    new Literal('+'),
    new Literal('*'),
    new Literal('?'),
    new Seq(
      new Literal('{'),
      new Lookup("num",$g),
      new Multi(new Lookup("quantmax",$g),0,1),
      new Literal('}'))));
  $g->{patterns}->{"lookahead"}=(new Seq(
    new Literal('?'),
    new Literal('=')));
  $g->{patterns}->{"pelems"}=(new Seq(
    new Lookup("pelem",$g),
    new Multi(new Lookup("pelem",$g),0,2147483647)));
  $g->{patterns}->{"name"}=(new Seq(
    new Multi(new Literal('-'),0,1),
    (new Bracket(0))
      ->addRange(':',':')
      ->addRange('A','Z')
      ->addRange('_','_')
      ->addRange('a','z')
      ,
    new Multi((new Bracket(0))
      ->addRange('0',':')
      ->addRange('A','Z')
      ->addRange('_','_')
      ->addRange('a','z')
      ,0,2147483647)));
  $g->{patterns}->{"charclass"}=(new Seq(
    new Literal('['),
    new Multi(new Lookup("neg",$g),0,1),
    new Multi(new Or(
      new Lookup("range",$g),
      new Lookup("echar",$g)),0,1),
    new Multi(new Or(
      new Lookup("range",$g),
      new Lookup("cchar",$g)),0,2147483647),
    new Multi(new Lookup("echar",$g),0,1),
    new Literal(']')));
  $g->{patterns}->{"neglookahead"}=(new Seq(
    new Literal('?'),
    new Literal('!')));
  return $g;
}


sub fileparserGenerator() {
  my $g = new Grammar();
  $g->{patterns}->{"boundary"}=(new Seq(
    new Literal("\\"),
    new Literal('b')));
  $g->{patterns}->{"backref"}=(new Seq(
    new Literal("\\"),
    (new Bracket(0))
      ->addRange('1','9')
      ));
  $g->{patterns}->{"named"}=(new Seq(
    new Literal('{'),
    new Lookup("name",$g),
    new Literal('}')));
  $g->{patterns}->{"echar"}=(new Literal('-'));
  $g->{patterns}->{"num"}=(new Multi((new Bracket(0))
    ->addRange('0','9')
    ,1,2147483647));
  $g->{patterns}->{"dot"}=(new Literal('.'));
  $g->{patterns}->{"pattern"}=(new Or(
    new Lookup("group_top",$g),
    new Nothing()));
  $g->{patterns}->{"range"}=(new Seq(
    new Lookup("cchar",$g),
    new Literal('-'),
    new Lookup("cchar",$g)));
  $g->{patterns}->{"rule"}=(new Seq(
    new Lookup("name",$g),
    new Lookup("-w",$g),
    new Literal('='),
    new Lookup("-w",$g),
    new Lookup("pattern",$g)));
  $g->{patterns}->{"pelems_next"}=(new Seq(
    new Multi(new Lookup("s",$g),0,1),
    new Literal('|'),
    new Multi(new Lookup("s",$g),0,1),
    new Lookup("pelem",$g),
    new Multi(new Seq(
      new Multi(new Lookup("s0",$g),0,1),
      new Lookup("pelem",$g)),0,2147483647)));
  $g->{patterns}->{"literal"}=(new Or(
    new Seq(
      new Literal("\\"),
      new Literal('u'),
      new Lookup("hex",$g)),
    new Seq(
      new Literal("\\"),
      (new Bracket(1))
        ->addRange('1','9')
        ->addRange('b','b')
        ),
    (new Bracket(1))
      ->addRange("\n","\n")
      ->addRange("\r","\r")
      ->addRange('$','$')
      ->addRange('(','+')
      ->addRange('.','.')
      ->addRange('?','?')
      ->addRange('[','^')
      ->addRange('{','}')
      ));
  $g->{patterns}->{"neg"}=(new Literal('^'));
  $g->{patterns}->{"file"}=(new Seq(
    new Start(),
    new Multi(new Lookup("-s",$g),0,1),
    new Lookup("rule",$g),
    new Multi(new Seq(
      new Multi(new Lookup("-s",$g),0,1),
      new Lookup("rule",$g)),0,2147483647),
    new Multi(new Lookup("-s",$g),0,1),
    new End()));
  $g->{patterns}->{"cchar"}=(new Or(
    new Seq(
      new Literal("\\"),
      new Literal('u'),
      new Lookup("hex",$g)),
    new Seq(
      new Literal("\\"),
      (new Bracket(1))
        ),
    (new Bracket(1))
      ->addRange('-','-')
      ->addRange("\\",']')
      ));
  $g->{patterns}->{"hex"}=(new Multi((new Bracket(0))
    ->addRange('0','9')
    ->addRange('A','F')
    ->addRange('a','f')
    ,4,4));
  $g->{patterns}->{"pipe"}=(new Nothing());
  $g->{patterns}->{"end"}=(new Literal('$'));
  $g->{patterns}->{"s0"}=(new Multi((new Bracket(0))
    ->addRange("\t","\t")
    ->addRange(' ',' ')
    ,1,2147483647));
  $g->{patterns}->{"pelems_top"}=(new Seq(
    new Lookup("pelem",$g),
    new Multi(new Seq(
      new Multi(new Lookup("s0",$g),0,1),
      new Lookup("pelem",$g)),0,2147483647)));
  $g->{patterns}->{"group"}=(new Seq(
    new Literal('('),
    new Or(
      new Lookup("ign_on",$g),
      new Lookup("ign_off",$g),
      new Lookup("lookahead",$g),
      new Lookup("neglookahead",$g),
      new Nothing()),
    new Or(
      new Lookup("group_inside",$g),
      new Nothing()),
    new Literal(')')));
  $g->{patterns}->{"ign_on"}=(new Seq(
    new Literal('?'),
    new Literal('i'),
    new Literal(':')));
  $g->{patterns}->{"pelem"}=(new Or(
    new Seq(
      new Or(
        new Lookup("named",$g),
        new Lookup("dot",$g),
        new Lookup("backref",$g),
        new Lookup("literal",$g),
        new Lookup("charclass",$g),
        new Lookup("group",$g)),
      new Or(
        new Lookup("quant",$g),
        new Nothing())),
    new Or(
      new Lookup("start",$g),
      new Lookup("end",$g),
      new Lookup("boundary",$g))));
  $g->{patterns}->{"nothing"}=(new Nothing());
  $g->{patterns}->{"group_inside"}=(new Seq(
    new Lookup("pelems",$g),
    new Multi(new Seq(
      new Literal('|'),
      new Lookup("pelems",$g)),0,2147483647),
    new Or(
      new Seq(
        new Multi(new Lookup("s0",$g),0,1),
        new Lookup("nothing",$g),
        new Literal('|')),
      new Nothing()),
    new Multi(new Lookup("s",$g),0,1)));
  $g->{patterns}->{"start"}=(new Literal('^'));
  $g->{patterns}->{"quantmax"}=(new Seq(
    new Literal(','),
    new Multi(new Lookup("num",$g),0,1)));
  $g->{patterns}->{"ign_off"}=(new Seq(
    new Literal('?'),
    new Literal('-'),
    new Literal('i'),
    new Literal(':')));
  $g->{patterns}->{"quant"}=(new Or(
    new Literal('+'),
    new Literal('*'),
    new Literal('?'),
    new Seq(
      new Literal('{'),
      new Lookup("num",$g),
      new Multi(new Lookup("quantmax",$g),0,1),
      new Literal('}'))));
  $g->{patterns}->{"lookahead"}=(new Seq(
    new Literal('?'),
    new Literal('=')));
  $g->{patterns}->{"s"}=(new Multi(new Or(
    (new Bracket(0))
      ->addRange("\t","\n")
      ->addRange("\r","\r")
      ->addRange(' ',' ')
      ,
    new Seq(
      new Literal('#'),
      new Multi(new Dot(),0,2147483647))),1,2147483647));
  $g->{patterns}->{"pelems"}=(new Seq(
    new Multi(new Seq(
      new Multi(new Lookup("s",$g),0,1),
      new Lookup("pelem",$g)),1,2147483647),
    new Multi(new Lookup("s",$g),0,1)));
  $g->{patterns}->{"group_top"}=(new Seq(
    new Lookup("pelems_top",$g),
    new Multi(new Lookup("pelems_next",$g),0,2147483647),
    new Or(
      new Seq(
        new Multi(new Lookup("s",$g),0,1),
        new Lookup("nothing",$g),
        new Literal('|')),
      new Nothing())));
  $g->{patterns}->{"w"}=(new Multi((new Bracket(0))
    ->addRange("\t","\t")
    ->addRange(' ',' ')
    ,0,2147483647));
  $g->{patterns}->{"name"}=(new Seq(
    new Multi(new Literal('-'),0,1),
    (new Bracket(0))
      ->addRange(':',':')
      ->addRange('A','Z')
      ->addRange('_','_')
      ->addRange('a','z')
      ,
    new Multi((new Bracket(0))
      ->addRange('0',':')
      ->addRange('A','Z')
      ->addRange('_','_')
      ->addRange('a','z')
      ,0,2147483647)));
  $g->{patterns}->{"charclass"}=(new Seq(
    new Literal('['),
    new Multi(new Lookup("neg",$g),0,1),
    new Multi(new Or(
      new Lookup("range",$g),
      new Lookup("echar",$g)),0,1),
    new Multi(new Or(
      new Lookup("range",$g),
      new Lookup("cchar",$g)),0,2147483647),
    new Multi(new Lookup("echar",$g),0,1),
    new Literal(']')));
  $g->{patterns}->{"neglookahead"}=(new Seq(
    new Literal('?'),
    new Literal('!')));
  return $g;
}
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
package piraha;
use strict;
use FileHandle;

$main::indent=0;

sub parse_peg_file
{
  my $peg = shift;
  local $/ = undef;
  my $fd = new FileHandle;
  open($fd,$peg) or die "cannot open $peg";
  my $peg_contents = <$fd>;
  close($fd);
  return parse_peg_src($peg_contents);
}

sub parse_peg_src
{
  my $peg_contents = shift;
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
        $m->fail($self->{ranges});
        return 0;
      }
    }
  }
  if(!$self->{neg}) {
    $m->fail($self->{ranges});
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
    $m->fail($self->{c});
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
    $m->fail($self->{lc});
    $m->fail($self->{uc});
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
  my $m  = shift;
  my $p  = $m->{textPos};
  my $h  = $m->{hash};
  my $mx = $m->{maxTextPos};
  my $b = $self->{pat}->match($m);
  $m->{textPos}=$p;
  $m->{maxTextPos}=$mx;
  $m->{hash} = $h;
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
  my $nm = shift;
  $n += $self->groupCount()+1+$n if($n < 0);
  my $ref = $self->{children}->[$n];
  unless(defined($ref)) {
    confess("invalid group index: $n");
  }
  if(defined($nm)) {
    my $m = $ref->{name};
    confess("wrong group '$nm' != '$m'")
      unless($m eq $nm);
  }
  return $ref;
}

sub has
{
  my $self = shift;
  my $n = shift;
  my $nm = shift;
  $n += $self->groupCount()+1+$n if($n < 0);
  my $ref = $self->{children}->[$n];
  return 0 unless(defined($ref));
  if(defined($nm)) {
    my $m = $ref->{name};
    return 0
      unless($m eq $nm);
  }
  return $ref;
}

sub is
{
  my $self = shift;
  my $nm = shift;
  return $self->{name} eq $nm;
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

sub linenum
{
  my $self = shift;
  my $n = 1;
  my $t = substr($self->{text},0,$self->{start});
  while($t =~ s/\n/$n++/ge){}
  return $n;
}

sub mkstring
{
  my $self = shift;
  my $tween = shift;
  $tween = " " unless(defined($tween));
  confess("bad self") unless(defined($self->{children}) and ref($self->{children}) eq "ARRAY");
  if($#{$self->{children}} < 0) {
    return $self->substring();
  } else {
    my $buf = "";
    for my $child (@{$self->{children}}) {
      $buf .= $tween unless($buf eq "");
      $buf .= $child->mkstring($tween);
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

sub expand_char
{
  my $k = shift;
  if($k eq "\t") {
    $k = "TAB";
  } elsif($k eq "\n") {
    $k = "NEWLINE";
  } elsif($k eq "\r") {
    $k = "RETURN";
  } elsif($k eq "'") {
    $k = "SINGLE_QUOTE";
  } elsif($k eq "\"") {
    $k = "DOUBLE_QUOTE";
  } elsif($k eq "`") {
    $k = "BACK_QUOTE";
  } elsif($k eq "\b") {
    $k = "BACKSPACE";
  } elsif($k eq "\e") {
    $k = "ESC";
  } else {
    $k = "'${k}'";
  }
  return $k;
}

sub show
{
  print "SHOW\n";
  my $self = shift;
}

sub showError
{
  my $self = shift;
  my $pos = $self->{maxTextPos};
  my $txt = $self->{text};
  my $pre = substr($txt,0,$pos);
  my $line = 1;
  while($pre =~ /\n/g) {
    $line++;
  }
  print "ERROR ON LINE $line:\n";
  if($pre =~ /.*\n.*\n.*\n*$/) {
    $pre = $&.$';
  }
  my $post = substr($txt,$pos+1);
  if($post =~ /.*/) {
    $post = $&;
  }
  $post =~ s/\n*$/\n/;
  my %hash = %{$self->{hash}};

  # Don't worry about comment characters
  delete $hash{" "};
  delete $hash{"#"};
  delete $hash{"\t"};
  delete $hash{"\n"};
  delete $hash{"\b"};
  delete $hash{"\r"};

  my $c = substr($txt,$pos,1);
  #print $pre,"\e[1;37;41m",$c,"\e[0;m",$post;
  print $pre,$c,$post;
  $pre =~ /.*$/;
  print " " x length($&),"^\n";
  print " " x length($&),"| here\n";
  my @out = ();
  my @count = ();
  my @k = sort keys %hash;
  for my $k (@k) {
    if($k =~ /[b-zB-Z1-9]/ and ord($k) == ord($out[$#out]) + $count[$#count]) {
      $count[$#count]++;
    } else {
      $out[$#out+1]=$k;
      $count[$#count+1]=1;
    }
  }
  my @out2 = ();
  for(my $i=0;$i<=$#out;$i++) {
    if($count[$i]==1) {
      my $k = $out[$i];
      $out2[$#out2+1] = expand_char($k);
    } elsif($count[$i]==2) {
      my $k = $out[$i];
      $out2[$#out2+1]="'${k}'";
      $out2[$#out2+1]="'".chr(ord($k)+1)."'";
    } else {
      my $k = $out[$i];
      $out2[$#out2+1]="'$k' to '".chr(ord($k)+$count[$i]-1)."'";
    }
  }
  print "FOUND CHARACTER: ",expand_char($c),"\n";
  print "EXPECTED CHARACTER(S): ",join(", ",@out2),"\n";
}

sub upos
{
  my $self = shift;
  my $pos = shift;
  $self->{textPos} = $pos;
  if($pos > $self->{maxTextPos}) {
    $self->{maxTextPos} = $pos;
    $self->{hash} = {};
  }
}

sub inc_pos
{
  my $self = shift;
  my $pos = ++$self->{textPos};
  if($pos > $self->{maxTextPos}) {
    $self->{maxTextPos} = $pos;
    $self->{hash} = {};
  }
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

use Data::Dumper;

sub fail
{
  my $self = shift;
  my $c = shift;
  if($self->{textPos} > $self->{maxTextPos}) {
    $self->{maxTextPos} = $self->{textPos};
    $self->{hash} = {};
  } elsif($self->{textPos} == $self->{maxTextPos}) { 
    ;#$self->{hash}->{$c} = 1;
  } else {
    return;
  }
  if(ref($c) eq "ARRAY") {
    for my $r (@$c) {
      for(my $n=$r->[0];$n <= $r->[1];$n++) {
        $self->{hash}->{chr($n)}=1;
      }
    }
  } else {
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
