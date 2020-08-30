package MooX::Role::RunAlone;

use 5.006;
use strict;
use warnings;

use Fcntl ':flock';

#use Moo::Role;
use Role::Tiny;

our $VERSION = 'v0.0.0_02';

my $verbose = !!$ENV{VERBOSE_RUNALONE};
my $retry   = $ENV{RETRY_RUNALONE};

my $data_pkg = 'main::DATA';

my @call_info = caller(6);
my $pkg       = $call_info[0];

sub runalone_lock {
    no strict 'refs';
    no warnings;    # to shut up "tell() on unopened filehandle"
    if ( tell( *{$data_pkg} ) == -1 ) {

        # if we reach this then the __END__ tag does not exist. swap in the
        # calling script namespace to see if the __DATA__ tag exists.
        $data_pkg = $pkg . '::DATA';

        if ( ( tell( *{$data_pkg} ) == -1 ) ) {
            warn "FATAL: No __DATA__ or __END__ tag found\n";
            exit 2;
        }
    }

    # are we alone?
    use warnings;    # safe to turn these on again
    if ( !flock( *{$data_pkg}, LOCK_EX | LOCK_NB ) ) {

        # retry if requested
        if ($retry) {
            warn "Retrying lock attempt ...\n" if $verbose;
            my ( $times, $sleep ) = split ',', $retry;
            $sleep ||= 1;
            while ( $times-- ) {
                sleep $sleep;

                # we're alone!
                goto ALLOK if flock *{$data_pkg}, LOCK_EX | LOCK_NB;
            }
            warn "Retrying lock failed ...\n" if $verbose;
        }

        # we're done
        warn "FATAL: A copy of '$0' is already running\n";
        exit 1;
    }

  ALLOK:
    return;
}

# deferring
if ( $ENV{DEFER_RUNALONE} ) {
    warn "Deferring " . __PACKAGE__ . " check for '$0'\n"
      unless $ENV{VERBOSE_RUNALONE};
}
else {
    __PACKAGE__->runalone_lock();
}

1;
__END__

=pod

=head1 NAME

MooX::Role::RunAlone - prevent multiple instances of a script from running

=head1 VERSION

Version v0.0.0_01

=head1 SYNOPSIS
  
 # in your script
 use Moo;
 with 'MooX::Role::RunAlone';
  
 ...
  
 __END__ # or __DATA__
  
=head1 DESCRIPTION

This module provides a simple way for a command line script that uses C<Moo>
to ensure that only a single instance of said script is able to run at
one time.

=head1 SUBROUTINES/METHODS

=head2 runalone_lock

=head1 ACKNOWLEDGMENTS

This module relies heavily upon a principle that was first proposed
(so far as this author knows) by Randal L. Schwartz (L<MERLYN>), and first
implemented by Elizibeth Mattijsen (L<ELIZABETH>) in L<Sys::RonAlone>. That
module has been extended by L<PERLANCAR> with suggestions by this author.

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


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2020 by Jim Bacon.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut
