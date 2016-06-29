#include "Piraha.hpp"
#include <stdlib.h>
#include <string.h>
use strict;

my $max_int = 2147483647;

#namespace cctki_piraha {
use Carp;
use array;

#char getChar(smart_ptr<Group> gr)
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
#smart_ptr<Pattern> mkMulti(smart_ptr<Group> g)
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


#void compileFile(smart_ptr<Grammar> g,const char *buffer,signed long buffersize)
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

#smart_ptr<Pattern> compile(smart_ptr<Group> g,bool ignCase,smart_ptr<Grammar> gram) 
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

#}
1;
