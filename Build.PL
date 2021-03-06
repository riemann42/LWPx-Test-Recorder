use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'LWPx::Test::Recorder',
    license             => 'perl',
    dist_author         => 'Edward Allen <ealleniii_at_cpan_dot_org>',
    dist_version_from   => 'lib/LWPx/Test/Recorder.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
        'LWP'        => 0,
        'File::Slurp' => 0,
    },
    add_to_cleanup      => [ 'LWPx-Test-Recorder-*' ],
    create_makefile_pl => 'traditional',
    use_tap_harness => 1,
    create_license => 1,
    release_status => 'unstable',
);

$builder->create_build_script();
