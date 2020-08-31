package MooX::Role::RunAlone;

use 5.006;
use strict;
use warnings;

use Fcntl ':flock';

#use Moo::Role;
use Role::Tiny;

our $VERSION = 'v0.0.0_02';

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
            exit 2;
        }
    }
}

# maybe the script wants to control this
__PACKAGE__->runalone_lock unless !!$ENV{RUNALONE_DEFER_LOCK};

sub runalone_lock {
    my $proto = shift;
    my %args  = @_;

    my $verbose  = !!delete( $args{verbose} );
    my $noexit   = !!delete( $args{noexit} );
    my $attempts = delete( $args{attempts} ) // 1;
    my $interval = delete( $args{interval} ) // 1;

    my $ret = 1;
    while ( $attempts-- > 0 ) {
        warn "attemting to lock $data_pkg ... " if $verbose;
        last if $proto->_runalone_lock($noexit);
        warn "failed. Retrying $attempts more time(s)\n" if $verbose;
        if ( $attempts ) {
            sleep $interval if $attempts;
        }
        else {
            $ret = 0;
            warn "FATAL: A copy of '$0' is already running\n";
            exit( 1 ) unless $noexit;
        }
    }
    warn "SUCCESS\n" if $verbose && $ret;

    return $ret;
}

# broken out for easier retry testing
sub _runalone_lock {
    my $proto  = shift;
    my $noexit = shift;

    no strict 'refs';
    return flock( *{$data_pkg}, LOCK_EX | LOCK_NB );
}

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
 package My::DeferedScript;
  
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
sctript's C<__DATA__> or C<__END__> section.

The Role will send a message to C<STDERR> indicating a fatal error and then
call C<exit(2)> if neither of those tags are present. This behavior can not
be disabled and occurs when the Role is composed.

=head2 NORMAL LOCKING

If one of the aforementioned tags are present, an attempt is made (via
C<runalone_lock()>) to obtain an exclusive lock on the tag's file handle
using C<flock> with the C<LOCK_EX> and C<LOCK_NB> flags set. A failure to
obtain an exclusive lock means that another instance of the composing
script is already executing. A message will be sent to C<STDERR> indicating
a fatal condition and the Role will call C<exit(1)>.

The Role does a void return if the call to C<flock> is successful.

=head2 DEFERRED LOCKING

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

=head1 METHODS

=head2 runalone_lock

=head3 Arguments

=over 4

=item noexit (Boolean, default: 0)

Controls whetern the method will call C<exit( 1 )> or return a Boolean
C<false> upon failure. Settin it C<true> allows the composing script
to take additional/different actions.

=item attempts (Integer, default: 1)

Set how many attempts will be made to get a lock on the handle in question.

=item interval (Integer, default: 1)

Sets how long to C<sleep> between attempts if C<attempts> is greater than one.

=item verbose (Boolean, default: 0)

Enables progress messages on STDERR if set. The following messages
can appear:
  
 "attemting to lock <data pkg> ... failed. Retrying <N> more time(s)"
 "attemting to lock <data pkg> ... SUCCESS"
  
=back

=head3 Returns

C<1> if the lock was obtained.

The method will either call C<exit(1)> or return a Boolean C<false> depending
upon the value of the C<noexit> argument.

=head1 UNDOCUMENTED METHODS

There are a number of methods used internally that are not documented here.
All such methods begin with the string C<_runalone_> in an attempt to
avoid namespace collision.

=head1 ACKNOWLEDGMENTS

This Role relies upon a principle that was first proposed (so far as this
author knows) by Randal L. Schwartz (L<MERLYN>), and first implemented by
Elizibeth Mattijsen (L<ELIZABETH>) in L<Sys::RonAlone>. That module has
been extended by L<PERLANCAR> in L<Sys::RunAlone::Flexible> with suggestions
by this author.

=head1 SEE ALSO

L<Sys::RunAlone>, L<Sys::RunAlone::Flexible>, L<Sys::RunAlone::Flexible2>

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
