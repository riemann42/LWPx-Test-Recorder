package LWPx::Test::Recorder;

use strict;
use warnings;
use Carp;
use version; our $VERSION = qv('0.0.3');

use base qw(LWP::UserAgent);
use Digest::MD5 qw(md5_hex);
use File::Slurp;
use File::Spec;
use List::Util qw(reduce);
use HTTP::Status qw(:constants);

sub new {
    my $class    = shift;
    my %defaults = (
        record        => 0,
        cache_dir     => 't/LWPCache',
        filter_params => [],
        filter_header => [qw(Client-Peer Expires Client-Date Cache-Control)],
    );
    my $params = shift || {};
    my $self = $class->SUPER::new(@_);
    $self->{_test_options} = { %defaults, %{$params} };
    return $self;
}

sub _filter_param {
    my ( $self, $key, $value ) = @_;
    my %filter = map { $_ => 1 } @{ $self->{_test_options}->{filter_params} };
    return join q{=}, $key, $filter{$key} ? q{} : $value;
}

sub _filter_all_params {
    my $self         = shift;
    my $param_string = shift;
    my %query =
        map { ( split qr{ = }xms )[ 0, 1 ] }
        split qr{ \& }xms, $param_string;
    return reduce { $a . $self->_filter_param( $b, $query{$b} ) }
    sort keys %query;
}

sub _get_cache_key {
    my ( $self, $request ) = @_;
    my $params = $request->uri->query() || q{};

    # TODO : Test if it is URL Encoded before blindly assuming.
    if ( $request->content ) {
        $params .= ($params) ? q{&} : q{};
        $params .= $request->content;
    }

    my $key =
          $request->method . q{ }
        . lc( $request->uri->host )
        . $request->uri->path . q{?}
        . $self->_filter_all_params($params);

    #warn "Key is $key";
    return File::Spec->catfile( $self->{_test_options}->{cache_dir},
        md5_hex($key) );
}

sub _filter_headers {
    my ( $self, $response ) = @_;
    foreach ( @{ $self->{_test_options}->{filter_header} } ) {
        $response->remove_header($_);
    }
    return;
}

sub request {
    my ( $self, @original_args ) = @_;
    my $request = $original_args[0];

    my $key = $self->_get_cache_key($request);

    if ( $self->{_test_options}->{record} ) {
        my $response = $self->SUPER::request(@original_args);

        my $cache_response = $response->clone;
        $self->_filter_headers($cache_response);
        $self->_set_cache( $key, $cache_response );

        return $response;
    }

    if ( $self->_has_cache($key) ) {
        return $self->_get_cache($key);
    }
    else {
        carp q{Page requested that wasn't recorded: }
            . $request->uri->as_string;
        return HTTP::Response->new(HTTP_NOT_FOUND);
    }
}

sub _set_cache {
    my ( $self, $key, $response ) = @_;
    write_file( $key, $response->as_string );
    return;
}

sub _has_cache {
    my ( $self, $key ) = @_;
    return ( -f $key );
}

sub _get_cache {
    my ( $self, $key ) = @_;
    my $file = read_file($key);
    return HTTP::Response->parse($file);
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

LWPx::Test::Recorder - An LWP User Agent which records and plays back requests
and responses.


=head1 VERSION

This document describes LWPx::Test::Recorder version 0.0.3


=head1 SYNOPSIS

    use lib('inc');
    use LWPx::Test::Recorder; 

    my $ua = LWPx::Test::Recorder->new({
        record => $ENV{LWP_RECORD},
        cache_dir => 't/LWPCache', 
        filter_params => [qw(password sessionid creditcard)],
    });

    My::Module->set_ua($ua);

  
=head1 DESCRIPTION

This module provides an alternative LWP UserAgent for use when testing a
module.  When it is asked to record, it quietly records responses in the
background.  When record option is set to false, it replays these, rather than
use the Internet.

Each response is a unique filename in a directory of your choosing.

I recommend that you ALWAYS use bundle this with any module that uses it.  The
key generating routines may change which would render the cache files useless.

If you change it for your own needs, and distribute the module, please add a
note to this POD to let others know it is not the same as the CPAN version.

For a very good alternative to this module, please see
L<LWPx::Record::DataSection>.  It may better suit your needs.

=head1 METHODS 

=over

=item new($option_ref)

This creates a new User Agent.  The first parameter is a hash reference of
options.  All additional options are passed onto LWP.

=item B<Options>

=over

=item record

When true, module is in record mode.  When false, it is in playback mode.  It
is convenient to set this to an environment variable (see L</SYNOPSIS>).

=item cache_dir

A directory to store the recordings in.

=item filter_params

This is an array reference of GET or POST parameters which will be removed when
generating the cache key.  Anything that may change between iterations, or
anything that is private (such as an api key), should be listed here.

=item filter_header

This is an array reference of headers to not include in stored response.  The
default is [qw(Client-Peer Expires Client-Date Cache-Control)].

=back

=item request()

This is method is overridden from L<LWP::UserAgent> to do our magic. 

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over


=item Page requested that wasn't recorded: %s

If a page is requested that was not recorded is not available, it will produce
this warning AND return a 404 Page Not Found error.

In the future, this may either croak or pass through to LWP.

=back

=head1 CONFIGURATION AND ENVIRONMENT

LWPx::Test::Recorder requires no configuration files or environment variables.


=head1 DEPENDENCIES

LWP is required for this to work, as it is a subclass of LWP::UserAgent.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

=over

=item Does not work transparently.

Unlike L<LWPx::Record::DataSection>, this module does not work transparently.
It is a subclass of L<LWP::UserAgent>.  This is not an issue if changing the
user agent is a trivial tasks in your module, but may be a show stopper if
this is not an option.

=item Does not store information in headers.

Currently there is no support for Cookies, etc. 

=back

Please report any bugs or feature requests to either:

=over

=item add git info here

=item C<bug-test-lwp-recorder@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Edward Allen  C<< <ealleniii_at_cpan_dot_org> >>


=head1 LICENSE

Copyright (c) 2011, Edward Allen C<< <ealleniii_at_cpan_dot_org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
