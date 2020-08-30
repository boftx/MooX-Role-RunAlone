use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME               => 'MooX::Role::RunAlone',
    AUTHOR             => q{Jim Bacon <boftx@cpan.org>},
    VERSION_FROM       => 'lib/MooX/Role/RunAlone.pm',
    ABSTRACT_FROM      => 'lib/MooX/Role/RunAlone.pm',
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => '5.006',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More'  => '0',
        'FindBin'     => '0',
        'Moo'         => '0',
        'Role::Tiny'  => '0',
        'Time::HiRes' => '0',
        'IPC::Run'    => '0',
        'File::Temp'  => '0',
    },
    PREREQ_PM => {
        'Moo'        => '0',
        'Role::Tiny' => '0',
        'Fcntl'      => '0',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'MooX-Role-RunAlone-*' },
);

# Compatibility with old versions of ExtUtils::MakeMaker
unless ( eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 } ) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$test_requires } =
      values %$test_requires;
}

unless ( eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 } ) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$build_requires } =
      values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
  unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);

package MY;
sub depend {
  "
mytests :: test xtest

xtest :
	\$(MAKE) test TEST_FILES=xt/*.t RELEASE_TESTING=1
"
}

__END__
