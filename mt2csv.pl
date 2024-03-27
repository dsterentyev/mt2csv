#!/usr/bin/perl

$lines = [];

while(<>)
{
    chomp;
    push(@$lines, $_);
}

%keys = ();

$lines3 = ();
$lines2 = prefilter_config($lines, 0);
foreach $ln (@$lines2)
{
    $lnh = parse_line($ln);
    undef($lnh->{'_params'});
    foreach $key (keys %$lnh)
    {
        $keys{$key} = 1;
    }
    push(@lines3, $lnh);
}

@skeyst = sort keys %keys;
@skeys = ("_section", "_action");
foreach (@skeyst)
{
    push(@skeys, $_) if $_ ne "_section" && $_ ne "_action" && $_ ne "comment";
}
push(@skeys, "comment");

print ';' . join(';', @skeys) . "\n";
$cnt = 0;
foreach $lnh (@lines3)
{
    @ln = ();
    push(@ln, $cnt);
    foreach $key (@skeys)
    {
        push(@ln, defined($lnh->{$key}) ? $lnh->{$key} : '');
    }
    $cnt++;
    print join(';', @ln) . "\n";
}

#skip notes and combine multiline statements into single line
#also checking for 
sub prefilter_config
{
    my $contl = '';
    my $c = 0;
    my @conf = ();
    my $bline;              # last line that start from /
    my $ncnt = 0;           # counter of lines that started from /
    my $bscnt = 0;          # counter of lines that not started from /
    foreach (@{$_[0]})
    {
        chomp;
        $c++;
        if(/^\#/)
        {
            if($ncnt > 0 && $_[1] == 1)
            {
                warn("In section '$bline' of master router config found followed RouterOS note: \n\#$_\n");
                die("Possible config is in inconsistent state. Unpredictable results may accurs, stopping work\n");
            }
            next;
        };
        s/^\s+//;
        s/\s+$//;
        #check for multiline statement
        if(! /^\// && $contl eq '')
        {
            $_ = "$bline $_";
            if($bscnt == 0)
            {
                pop(@conf);
                $bscnt++;
            }
        }
        else
        {
            $bline = $_;
            $bscnt = 0;
            $ncnt++;
        }
        my $cont = /\\\s*$/ ? 1 : 0;
        if($cont)
        {
            s/\\\s*$//;
            $contl .= $_;
        }
        else
        {
            push(@conf, $contl . $_);
            $contl = '';
        }
    }
    return(\@conf);
}

#split single line to branch, action and parameters
sub parse_line
{
    my $line =  $_[0];
    my %vals = ();
    $_ = $line;
    if(s/^\/([\d\w\- ]+)\s+(add|set)\s*$// || s/^\/([\d\w\- ]+)\s+(add|set)\b\s+//)
    {
        $vals{'_section'} = $1;
        $vals{'_action'} = $+;
        $vals{'_params'} = $_;
        my $params = $_;
        my $st = 0; 
        my $ch = '';
        my $pch = '';
        my $vkey = '';
        my $vval = '';
        my $quot = 0;
        my $rquot = 0;
        for(my $c = 0; $c <= length($params); $c++)
        {
            $pch = $ch;
            $ch = substr($params, $c, 1);
            if($st == 0 && $quot == 0 && $ch eq '[')
            {
                $quot = 1;
                $vkey = '';
            }
            elsif($st == 0 && $quot == 1 && $ch eq ']')
            {
                $quot = 0;
                $vkey =~ s/^\s+//;
                $vkey =~ s/\s+$//;
                $vals{3} = $vkey if $vkey ne '';
                $vkey = '';
            }
            elsif($st == 0 && $quot == 1)
            {
                $vkey .= $ch;
            }
            elsif($st == 0 && $ch eq '=')
            {
                $st = 1;
                $vval = '';
            }
            elsif($st == 0 && $ch eq ' ')
            {
                $vals{$vkey} = '' if $vkey ne '';
                $vkey = '';
            }
            elsif($st == 0)
            {
                $vkey .= $ch;
            }
            elsif($st == 1 && $quot == 0 && $ch eq '"')
            {
                $quot = 1;
            }
            elsif($st == 1 && $quot == 1 && $rquot == 0 && $ch eq "\\")
            {
                $rquot = 1;
                $vval .= $ch;
            }
            elsif($st == 1 && $quot == 1 && $rquot == 1 && $ch =~ /[0-9A-F]/)
            {
                $rquot = 2;
                $vval .= $ch;
            }
            elsif($st == 1 && $quot == 1 && $rquot == 1 && $ch =~ /[\"\\nrt\$\?\_abfv]/)
            {
                $rquot = 0;
                $vval .= $ch;
            }
            elsif($st == 1 && $quot == 1 && $rquot == 1)
            {
                die("error: can't parse single char quote (in pos $c) in $params\n");
            }
            elsif($st == 1 && $quot == 1 && $rquot == 2 && $ch =~ /[0-9A-F]/)
            {
                $rquot = 0;
                $vval .= $ch;
            }
            elsif($st == 1 && $quot == 1 && $rquot == 2)
            {
                die("error: can't parse double char quote (in pos $c) in $params\n");
            }
            elsif($st == 1 && $quot == 1 && $ch eq '"')
            {
                $quot = 0;
            }
            elsif($st == 1 && $quot == 1 && $ch eq ' ')
            {
                $vval .= $ch;
            }
            elsif($st == 1 && $ch eq ' ')
            {
                $vals{$vkey} = $vval;
                $st = 0;
                $vkey = '';
                $vval = '';
            }
            else
            {
                $vval .= $ch;
            }
        }
        $vals{$vkey} = $vval if $vkey ne '';
    }
    else
    {
        die("error: can't parse: $line\n");
    }
    return(\%vals);
}
