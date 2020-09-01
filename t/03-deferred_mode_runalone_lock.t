#!perl

$| = 1;

use 5.006;
use strict;
use warnings;

use Test::More tests => 7;
use Test::MockSleep;
use Test::MockModule;

use FindBin;
use lib $FindBin::Bin . '/../lib';

BEGIN {
    $ENV{RUNALONE_DEFER_LOCKING} = 1;
}

my $pkg = 'MooX::Role::RunAlone';

my $ral_ran = 0;
my $_ral_val;
my $_ral_cnt;
my $mock_MRR = Test::MockModule->new($pkg);
$mock_MRR->mock(
    runalone_lock  => sub { return $ral_ran = 1; },
    _runalone_lock => sub { return ++$_ral_cnt > 3 ? 1 : $_ral_val; },
    _runalone_exit => sub { die 'exit called'; },
);

require_ok($pkg) || print "Bail out!\n";
is( $ral_ran, 0, 'runalone_lock not called with RUNLONE_DEFER_LOCKING set' );

# no longer needed for the rest of the tests
$mock_MRR->unmock('runalone_lock');

subtest 'no args' => sub {
    plan tests => 5;

    $_ral_val = 0;
    $_ral_cnt = 0;

    my $stderr = '';
    eval {
        local $SIG{__WARN__} = sub { $stderr .= $_[0]; };
        $pkg->runalone_lock;
    };
    ok( $@, 'missing "noexit" arg allows exit() to be called' );
    like( $stderr, qr/FATAL/, 'and did not suppress the error message' );
    is( $_ral_cnt, 1, 'missing "attempts" does only one attempt' );
    unlike( $stderr, qr/atempting/, 'no verbose messages present' );
    ok( !slept(), 'sleep was not called after a single check' );
};

subtest noexit => sub {
    plan tests => 4;

    $_ral_val = 0;

    my $stderr = '';
    eval {
        local $SIG{__WARN__} = sub { $stderr .= $_[0]; };
        $pkg->runalone_lock( noexit => 1 );
    };
    ok( !$@, 'noexit stops exit() being called' );
    is( $stderr, '', 'and suppressed the error message' );

    eval {
        $stderr = '';
        local $SIG{__WARN__} = sub { $stderr .= $_[0]; };
        $pkg->runalone_lock( noexit => 0 );
    };
    ok( $@, 'false noexit allows exit() to be called' );
    like( $stderr, qr/FATAL/, 'and did not suppress the error message' );
};

subtest attempts => sub {
    plan tests => 9;

    $_ral_val = 0;
    $_ral_cnt = 0;

    eval {
        local $SIG{__WARN__} = sub { };
        $pkg->runalone_lock( attempts => 3 );
    };
    is( $_ral_cnt, 3, '3 attempts were made' );
    is( slept(),   2, 'sleep was not called after final attempt' );

    $_ral_cnt = 0;
    eval {
        local $SIG{__WARN__} = sub { };
        $pkg->runalone_lock( attempts => 5 );
    };
    is( $_ral_cnt, 4, 'retry loops stops upon success' );
    is( slept(),   3, 'sleep was not called after successful attempt' );

    my @bad_cases = (
        {
            name  => '"attempts" = foo',
            arg   => 'attempts',
            value => 'foo',
        },
        {
            name  => '"attempts" = 0',
            arg   => 'attempts',
            value => 0,
        },
        {
            name  => '"attempts" = -1',
            arg   => 'attempts',
            value => 0,
        },
        {
            name  => '"attempts" = 10',
            arg   => 'attempts',
            value => 0,
        },
        {
            name  => '"attempts" = 1.5',
            arg   => 'attempts',
            value => 0,
        },
    );

    for (@bad_cases) {
        eval { $pkg->runalone_lock( $_->{arg} => $_->{value} ); };
        like( $@, qr/$_->{arg}: invalid/, qq{$_->{name}: rejected} );
    }
};

subtest interval => sub {
    plan tests => 9;

    $_ral_val = 0;
    $_ral_cnt = 0;

    eval {
        local $SIG{__WARN__} = sub { };
        $pkg->runalone_lock( attempts => 2 );
    };
    is( $_ral_cnt, 2, '2 attempts were made' );
    is( slept(),   1, 'interval defaults to 1' );

    $_ral_val = 0;
    $_ral_cnt = 0;
    eval {
        local $SIG{__WARN__} = sub { };
        $pkg->runalone_lock( interval => 2, attempts => 3 );
    };
    is( $_ral_cnt, 3, '3 attempts were made' );
    is( slept(),   4, 'time slept equals (attempts - 1) * interval' );

    my @bad_cases = (
        {
            name  => '"interval" = foo',
            arg   => 'interval',
            value => 'foo',
        },
        {
            name  => '"interval" = 0',
            arg   => 'interval',
            value => 0,
        },
        {
            name  => '"interval" = -1',
            arg   => 'interval',
            value => 0,
        },
        {
            name  => '"interval" = 10',
            arg   => 'interval',
            value => 0,
        },
        {
            name  => '"interval" = 1.5',
            arg   => 'interval',
            value => 0,
        },
    );

    for (@bad_cases) {
        eval { $pkg->runalone_lock( $_->{arg} => $_->{value} ); };
        like( $@, qr/$_->{arg}: invalid/, qq{$_->{name}: rejected} );
    }
};

subtest 'unknown argument' => sub {
    plan tests => 1;
    eval { $pkg->runalone_lock( foobar => 2 ); };
    like( $@, qr/ERROR: unknown argument/, 'unknown arguments are rejected' );
};

done_testing();
exit;

__END__
