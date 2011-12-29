package Plack::Middleware::MultiSession;
use strict;
use warnings;

our $VERSION = '0.001';

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

