#!perl
use 5.006;

use strict;
use warnings;

use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

use Test::Pod::Spelling;
add_stopwords(
    qw(
      Mattijsen
      cronjobs
      noexit
      init
      negatable
      perldoc
      AnnoCPAN
      CPAN
      licensable
      sym
      Symlinks
      )
);

TODO: {
    local $TODO = "Need to correct spelling mistakes";

    all_pod_files_spelling_ok();
}

done_testing();
exit;

__END__
