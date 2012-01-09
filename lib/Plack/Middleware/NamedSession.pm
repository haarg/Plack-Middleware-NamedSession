use strict;
use warnings;
package Plack::Middleware::NamedSession;
# ABSTRACT: Creates named sessions, allowing multiple simultaneously

use parent 'Plack::Middleware';

use Plack::Util;
use Plack::Util::Accessor qw(
    name
    session_mw
);
use Scalar::Util ();

sub prepare_app {
    my $self = shift;
    my $name = $self->name;
    my $app = $self->app;
    my $session_mw = $self->session_mw || $self->session_mw('Session');

    if (! Scalar::Util::blessed($session_mw)) {
        my %params = %$self;
        delete $params{name};
        delete $params{session_mw};
        $session_mw = Plack::Util::load_class($session_mw, 'Plack::Middleware')->new(%params);
    }

    my $wrap_app = $session_mw->wrap(sub {
        my $env = shift;
        # store ::Session created session
        my $session = delete $env->{'psgix.session'};
        my $options = delete $env->{'psgix.session.options'};
        my $name = $self->name;
        $env->{"session.$name"} = $session;
        $env->{"session.$name.options"} = $options;
        # restore old session
        if (exists $env->{'namedsession.backup'}) {
            $env->{'psgix.session'} = delete $env->{'namedsession.backup'};
            $env->{'psgix.session.options'} = delete $env->{'namedsession.backup.options'};
        }
        # call original app
        my $res = $app->($env);
        Plack::Util::response_cb($res, sub {
            # save old session
            if (exists $env->{'psgix.session'}) {
                $env->{'namedsession.backup'} = delete $env->{'psgix.session'};
                $env->{'namedsession.backup.options'} = delete $env->{'psgix.session.options'};
            }

            # restore our session
            my $session = delete $env->{"session.$name"};
            my $options = delete $env->{"session.$name.options"};
            $env->{'psgix.session'} = $session;
            $env->{'psgix.session.options'} = $options;
        });
    });

    $self->app($wrap_app);
}

sub call {
    my $self = shift;
    my $env  = shift;

    # save old session
    if (exists $env->{'psgix.session'}) {
        $env->{'namedsession.backup'} = delete $env->{'psgix.session'};
        $env->{'namedsession.backup.options'} = delete $env->{'psgix.session.options'};
    }

    my $res = $self->app->($env);
    Plack::Util::response_cb($res, sub {
        delete $env->{'psgix.session'};
        delete $env->{'psgix.session.options'};

        # restore old session
        if (exists $env->{'namedsession.backup'}) {
            $env->{'psgix.session'}         = delete $env->{'namedsession.backup'};
            $env->{'psgix.session.options'} = delete $env->{'namedsession.backup.options'};
        }
    });
}

1;

=head1 SYNOPSIS

    builder {
        enable 'NamedSession', name => 'permanant';
        $app;
    };

=head1 DESCRIPTION

Sets up a named session, allowing multiple to be in use at the same
time.

=head1 CONFIGURATION

=over 8

=item name

The name of the session.

=item session_mw

The middleware class or object to use for the named session.

=back

=head1 SEE ALSO

=for :list
* L<Plack::Middleware::Session>

=cut

