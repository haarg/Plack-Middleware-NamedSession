use strict;
use warnings;
package Plack::Middleware::MultiSession;
# ABSTRACT: Adds headers to allow Cross-Origin Resource Sharing
use parent qw(Plack::Middleware::Session);

use Plack::Util;
use Plack::Util::Accessor qw(
    name
);

use parent 'Plack::Middleware::Session';

sub call {
    my $self = shift;
    my $env  = shift;

    my $old_session = delete $env->{'psgix.session'};
    my $old_options = delete $env->{'psgix.session.options'};

    my $m_sessions = $env->{'psgix.sessions'} ||= {};
    my $m_options = $env->{'psgix.sessions.options'} ||= {};

    my $app = $self->app;
    my $wrap_app = sub {
        my $env = shift;
        if ($self->name) {
            $m_sessions->{$self->name} = $env->{'psgix.session'};
            $m_options->{$self->name} = $env->{'psgix.session.options'};
        }
        $app->($env);
    };
    $self->{app} = $app;
    my $res = $self->SUPER::call($env);

    $self->response_cb($res, sub {
        if (defined $old_session) {
            $env->{'psgix.session'} = $old_session;
            $env->{'psgix.sessions.options'} = $old_options;
        }
    });
}

1;

=head1 SYNOPSIS

    builder {
        enable 'MultiSession', name => 'permanant';
        $app;
    };

=head1 DESCRIPTION

Sets up a named session, allowing multiple to be in use at the same
time.

=head1 CONFIGURATION

=over 8

=item name

The name of the session.

=back

=head1 SEE ALSO

=for :list
* L<Plack::Middleware::Session>

=cut

