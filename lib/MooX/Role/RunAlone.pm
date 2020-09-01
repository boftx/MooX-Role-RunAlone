package MooX::Role::RunAlone;

use 5.006;
use strict;
use warnings;

use Fcntl qw( :flock );
use Carp qw( croak );

#use Moo::Role;
use Role::Tiny;

our $VERSION = 'v0.0.0_02';

my %default_lock_args = (
    noexit   => 0,
    attempts => 1,
    interval => 1,
    verbose  => 0,
);

my $data_pkg = 'main::DATA';

my @call_info = caller(6);
my $pkg       = $call_info[0];

# use a block because the pragmas are lexical scope and we need
# to stop warnings/errors from the call to "tell()"
{
    no strict 'refs';
    no warnings;

    if ( tell( *{$data_pkg} ) == -1 ) {

        # if we reach this then the __END__ tag does not exist. swap in the
        # calling script namespace to see if the __DATA__ tag exists.
        $data_pkg = $pkg . '::DATA';

        if ( ( tell( *{$data_pkg} ) == -1 ) ) {
            warn "FATAL: No __DATA__ or __END__ tag found\n";
            __PACKAGE__->_runalone_exit(2);
        }
    }
}

# maybe the script wants to control this
__PACKAGE__->runalone_lock unless !!$ENV{RUNALONE_DEFER_LOCK};

# is the argument validation over-engineered? maybe, but I'm paranoid.
sub runalone_lock {
    my $proto = shift;
    my %args  = @_;

    # set defaults as needed
    for ( keys(%default_lock_args) ) {
        $args{$_} //= $default_lock_args{$_};
    }

    croak 'ERROR: unknown argument present'
      if scalar( keys(%args) ) != scalar( keys(%default_lock_args) );

    # validate integer args
    for (qw( attempts interval )) {
        croak "$_: invalid value" unless $args{$_} =~ /^[1-9]$/;
    }

    # coerce Boolean args
    for (qw( noexit verbose )) {
        $args{$_} = !!$args{$_};
    }

    my $ret = 1;
    while ( $args{attempts}-- > 0 ) {
        warn "attemting to lock $data_pkg ... " if $args{verbose};
        last if $proto->_runalone_lock( $args{noexit} );
        warn "failed. Retrying $args{attempts} more time(s)\n"
          if $args{verbose};
        if ( $args{attempts} ) {
            sleep $args{interval} if $args{attempts};
        }
        elsif ( $args{noexit} ) {
            $ret = 0;
        }
        else {
            warn "FATAL: A copy of '$0' is already running\n";
            __PACKAGE__->_runalone_exit(1);
        }
    }
    warn "SUCCESS\n" if $args{verbose} && $ret;

    return $ret;
}

# no need to mock Perl internal exit for tests
sub _runalone_exit {
    my $proto  = shift;
    my $status = shift // 0;

    exit($status);
}

# broken out for easier retry testing
sub _runalone_lock {
    my $proto  = shift;
    my $noexit = shift;

    no strict 'refs';
    return flock( *{$data_pkg}, LOCK_EX | LOCK_NB );
}

# helper for test scripts
sub _runalone_tag_pkg {
    $data_pkg =~ /^(.+)::DATA$/;

    return $1;
}

1;
__END__

=pod

=head1 NAME

MooX::Role::RunAlone - prevent multiple instances of a script from running

=head1 VERSION

Version v0.0.0_01

=head1 SYNOPSIS
  
 # normal mode
 package My::Script;
  
 use strict;
 use warnings;
  
 use Moo;
 with 'MooX::Role::RunAlone';
  
 ...
  
 __END__ # or __DATA__
  

 # deferred mode
 package My::DeferredScript;
  
 BEGIN {
    $ENV{RUNALONE_DEFER_LOCK} = 1;
 }
  
 use strict;
 use warnings;
  
 use Moo;
 with 'MooX::Role::RunAlone';
  
 ...

 # exit immediately if we are not alone
 __PACKAGE__->runalone_lock;
  
 # do work
 ...
  
 __END__ # or __DATA__

=head1 DESCRIPTION

This Role provides a simple way for a command line script that uses C<Moo>
to ensure that only a single instance of said script is able to run at
one time. This is accomplished by trying to obtain an exlusive lock on the
script's C<__DATA__> or C<__END__> section.

The Role will send a message to C<STDERR> indicating a fatal error and then
call C<exit(2)> if neither of those tags are present. This behavior can not
be disabled and occurs when the Role is composed.

=head2 Normal Locking

If one of the aforementioned tags are present, an attempt is made (via
C<runalone_lock()>) to obtain an exclusive lock on the tag's file handle
using C<flock> with the C<LOCK_EX> and C<LOCK_NB> flags set. A failure to
obtain an exclusive lock means that another instance of the composing
script is already executing. A message will be sent to C<STDERR> indicating
a fatal condition and the Role will call C<exit(1)>.

The Role does a void return if the call to C<flock> is successful.

=head2 Deferred Locking

The composing script can tell the Role that it should not immediately
call C<runalone_lock()> but should defer this action to the script. This is
done like this:
  
 BEGIN {
    $ENV{RUNALONE_DEFER_LOCK} = 1;
 }
  
The Role will return immediately after checking to see whether or not
one of the tags are present instead of trying to get the lock.

Note: It is the responsibility of the composing script to call
C<runalone_lock()> at an appropriate time.

=head2 Fatal Messages

There are two messages that are sent to C<STDERR> that cannot usually be
suppressed during normal startup:

=over 4

=item "FATAL: No __DATA__ or __END__ tag found"


=item "FATAL: A copy of '$0' is already running"

Note: this can be suppressed in deferred locking mode. See the C<noexit>
argument to C<runalone_lock>.

=back

=head1 METHODS

Only one method is currently exposed, but it is the workhorse when deferred
mode is used.

=head2 runalone_lock

This method attempts to get an exclusive lock on the C<__END__> or C<__DATA__>
handle that was located during the Role's startup. A composing script may
immulate normal operation by simply calling this method with no arguments
at the desired time. It will either return a Boolean C<true> if successful,
or call C<exit> with a status code of C<1> upon failure.

The method's behavior can be modified by four arguments. This allows the
composing script to enable lock retries or perform custom operations as
needed. (Note: the method is implemented as a C<class method> and may be
called with either a class name or a composing object.

Examples:
  
 # basic call with retries and progress messages enabled
 my $locked = __PACKAGE__->runalone_lock(
    attempts => 3,
    interval => 2,
    verbose  => 1,
 );
  
 # basic call with retries enabled, but silent
 my $locked = __PACKAGE__->runalone_lock(
    attempts => 3,
    interval => 2,
 );
  
 # make a single (silent) attempt, but return to the caller instead of
 # exiting if the attempt fails. Also suppresses any failure message.
 my $locked = __PACKAGE__->runalone_lock(
    noexit => 1,
 );
  

=head3 Arguments

Invalid values will cause an exception to be thrown via C<croak> so the
offending caller might be more easily identified.

=over 4

=item noexit (Boolean, default: 0)

Controls whether the method will call C<exit( 1 )> or return a Boolean
C<false> upon failure. Setting it C<true> allows the composing script
to take additional/different actions.

Note: if set, it will also suppress the fatal error message associated
with failure to obtain a lock.

=item attempts (Integer, must satisfy 0 < N < 10; default: 1)

Set how many attempts will be made to get a lock on the handle in question.

=item interval (Integer, must satisfy 0 < N < 10, default: 1)

Sets how long to C<sleep> between attempts if C<attempts> is greater than one.

=item verbose (Boolean, default: 0)

Enables progress messages on STDERR if set. The following messages
can appear:
  
 "attemting to lock <data pkg> ... failed. Retrying <N> more time(s)"
 "attempting to lock <data pkg> ... SUCCESS"
  
=back

=head3 Returns

C<1> if the lock was obtained.

The method will either call C<exit(1)> or return a Boolean C<false> depending
upon the value of the C<noexit> argument.

=head1 PRIVATE METHODS

There are a few internal methods that are not documented here. All such
methods begin with the string C<_runalone_> in an attempt to avoid
namespace collision.

=head1 CAVEATS

[NB: This section has been copied from C<Sys::RunAlone>]

=head2 Symlinks

Execution of scripts that are (sym)linked to another script, will all be seen
as execution of the same script, even though the error message will only show
the specified script name.  This could be considered a bug or a feature.

=head2 Changing a Running Script

If you change the script while it is running, the script will effectively
lose its lock on the file. causing any subsequent run of the same script
to be successful, therefore causing two instances of the same script to run
at the same time (which is what you wanted to prevent by using Sys::RunAlone
in the first place). Therefore, make sure that no instances of the script are
running (and won't be started by cronjobs while making changes) if you really
want to be 100% sure that only one instance of the script is running at the
same time.

=head1 ACKNOWLEDGMENTS

This Role relies upon a principle that was first proposed (so far as this
author knows) by Randal L. Schwartz (L<MERLYN>), and first implemented by
Elizabeth Mattijsen (L<ELIZABETH>) in L<Sys::RunAlone>. That module has
been extended by L<PERLANCAR> in L<Sys::RunAlone::Flexible> with suggestions
by this author.

=head1 SEE ALSO

L<Sys::RunAlone>, L<Sys::RunAlone::Flexible>

=head1 AUTHOR

Jim Bacon, C<< <boftx at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-moox-role-runalone at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=MooX-Role-RunAlone>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MooX::Role::RunAlone


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=MooX-Role-RunAlone>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MooX-Role-RunAlone>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/MooX-Role-RunAlone>

=item * Search CPAN

L<https://metacpan.org/release/MooX-Role-RunAlone>

=back

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2020 by Jim Bacon.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut
