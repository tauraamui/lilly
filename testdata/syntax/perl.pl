#!/usr/bin/env perl
# Perl syntax stress file. Lexing only.
use strict;
use warnings;
use List::Util qw(sum max);

=pod

=head1 NAME

stress.pl - POD runs from a =word line to =cut.
Everything here, including "quotes" and $vars, is documentation.

=cut

my $scalar = 42;
my @array  = (1, 2, 3);
my %hash   = (key => 'value', other => "thing");
our $VERSION = '1.00';
local $_ = 'topic';

my $hex = 0xFF_FF;
my $bin = 0b1010;
my $float = 1_000.5e-3;

# sigils, element access, references, special vars
my $elem    = $array[0];
my $slice   = @array[0 .. 1];
my $count   = $#array;
my $hval    = $hash{key};
my @keys    = keys %hash;
my $aref    = \@array;
my $deref   = @{$aref};
my $code    = \&main::helper;
my $err     = $@;
my $pid     = $$;
my $match0  = $0;
my $sep     = $/;
my $caret   = ${^MATCH};
my $pkgvar  = $Some::Package::var;

my $double = "interp $scalar and @array and $hash{key} and \t\n \"escaped\"";
my $single = 'no interp $scalar, but \' is escaped';
my $multi  = "a double-quoted string
that spans
several lines";
my $cmd    = `ls -la \`nested\``;

sub helper {
    my ($self, %args) = @_;
    return unless defined $self;
    foreach my $item (@array) {
        next if $item == 1;
        last if $item eq 'stop' or $item gt 'z';
        redo unless $item;
    }
    for (my $i = 0; $i < 10; $i++) { }
    while (my ($k, $v) = each %hash) { }
    until ($scalar) { }
    if ($scalar <=> 1 and not $scalar cmp 'x') {
    } elsif ($scalar ne 2 xor $scalar le 3) {
    } else {
    }
    return wantarray ? @array : $scalar;
}

package Counter {
    sub new { my $class = shift; return bless { count => 0 }, $class }
    sub inc { $_[0]{count}++ }
}

print __PACKAGE__, " line ", __LINE__, "\n";

# KNOWN GAP: regexes and quote-like operators have no contexts
my ($first) = $double =~ m/interp (\w+)/;
(my $copy = $single) =~ s/'/"/g;
my $after_subst = 'did this recover?';
my @words = qw(alpha beta 'gamma' delta);
my $q = q{curly 'quoted' string};
my $qq = qq[bracket "quoted" $scalar];
$copy =~ tr/a-z/A-Z/;

# KNOWN GAP: heredocs lex as code
my $heredoc = <<"END";
Heredoc body with $scalar and 'quotes' and "more quotes"
END
my $after_heredoc = 1;

helper(Counter->new);

__END__

Anything after __END__ is data, not code.
