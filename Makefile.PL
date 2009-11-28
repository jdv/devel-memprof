use inc::Module::Install;

all_from 'lib/Devel/MemProf.pm';

recursive_author_tests( 'xt' );

WriteAll;
