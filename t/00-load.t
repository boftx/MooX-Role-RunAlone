#!perl -T

use 5.006;
use strict;
use warnings;

use Test::More tests => 1;

require_ok('MooX::Role::RunAlone') || print "Bail out!\n";

my $version = $MooX::Role::RunAlone::VERSION;
diag("Testing MooX::Role::RunAlone $version, Perl $], $^X");

exit;

__END__
