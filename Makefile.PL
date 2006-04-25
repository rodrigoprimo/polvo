use 5.008007;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Polvo',
    VERSION_FROM      => 'lib/Polvo.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    AUTHOR         => 'Fernando Freire <nano@>' 
);
