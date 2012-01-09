use strict;
use warnings;
package Plack::Middleware::NamedSession;
# ABSTRACT: Creates named sessions, allowing multiple simultaneously
use parent qw(Plack::Middleware::Session);

use Plack::Util;
use Plack::Util::Accessor qw(
    name
);

use parent 'Plack::Middleware::Session';

sub call {
    my $self = shift;
    my $env  = shift;

    # save old session
    my $orig_session = delete $env->{'psgix.session'};
    my $orig_options = delete $env->{'psgix.session.options'};

    my $app = $self->app;
    my $wrap_app = sub {
        my $env = shift;
        # store ::Session created session
        my $session = delete $env->{'psgix.session'};
        my $options = delete $env->{'psgix.session.options'};
        my $name = $self->name;
        $env->{"session.$name"} = $session;
        $env->{"session.$name.options"} = $options;
        # restore old session
        if (defined $orig_session) {
            $env->{'psgix.session'} = $orig_session;
            $env->{'psgix.session.options'} = $orig_options;
            undef $orig_session;
            undef $orig_options;
        }
        # call original app
        return $app->($env);
    };
    local $self->{app} = $wrap_app;
    return $self->SUPER::call($env);
}

sub finalize {
    my ($self, $env, $res) = @_;

    # save old session
    my $orig_session = delete $env->{'psgix.session'};
    my $orig_options = delete $env->{'psgix.session.options'};

    # restore our session
    my $name = $self->name;
    my $session = delete $env->{"session.$name"};
    my $options = delete $env->{"session.$name.options"};
    $env->{'psgix.session'} = $session;
    $env->{'psgix.session.options'} = $options;

    # call parent cleanup
    $self->SUPER::finalize($env, $res);

    delete $env->{'psgix.session'};
    delete $env->{'psgix.session.options'};

    # restore old session
    if (defined $orig_session) {
        $env->{'psgix.session'}         = $orig_session;
        $env->{'psgix.session.options'} = $orig_options;
    }
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

=back

=head1 SEE ALSO

=for :list
* L<Plack::Middleware::Session>

=cut

