use strict;
use warnings;
use Test::More 0.88;

use Plack::Middleware::NamedSession;
use Plack::Test;
use Plack::Builder;
use HTTP::Cookies;
use Plack::Session::State::Cookie;

sub with_cookies {
    my $cb = shift;
    my $jar = HTTP::Cookies->new;
    return sub {
        my $req = shift || HTTP::Request->new(GET => 'http://localhost/');
        $jar->add_cookie_header($req);
        my $res = $cb->($req);
        $jar->extract_cookies($res);
        return $res;
    };
}

my $app_cb = sub {};
test_psgi
    app => builder {
        enable 'NamedSession', name => 'coookies';
        sub {
            my $env = shift;
            my $res = [ 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ] ];
            $app_cb->($env, $res);
            return $res;
        };
    },
    client => sub {
        my $cb = with_cookies(shift);
        my $res;

        $app_cb = sub {
            my ($env, $res) = @_;
            ok ! (exists $env->{'psgix.session'}), 'standard session location not created';
        };
        $cb->();

        my $called;
        $app_cb = sub {
            my ($env, $res) = @_;
            $called = ++$env->{'session.coookies'}{called};
        };
        $cb->();
        $cb->();
        is $called, 2, 'session data maintained';
    };

test_psgi
    app => builder {
        enable 'Session', state => Plack::Session::State::Cookie->new(session_key => 'standard_session');
        enable sub {
            my $app = shift;
            sub {
                my $env = shift;
                $env->{'psgix.session'}{called}++;
                my $res = $app->($env);
                return $res;
            };
        };
        enable 'NamedSession', name => 'coookies';
        sub {
            my $env = shift;
            my $res = [ 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ] ];
            $app_cb->($env, $res);
            return $res;
        };
    },
    client => sub {
        my $cb = with_cookies(shift);
        my $res;

        my $called;
        $app_cb = sub {
            my ($env, $res) = @_;
            $called = $env->{'psgix.session'}{called};
        };
        $cb->();
        is $called, 1, 'outer standard session prepared';

        $cb->();
        is $called, 2, 'standard session restored';
    };

$app_cb = sub {};
test_psgi
    app => builder {
        enable 'NamedSession', name => 'coookies', session_mw => 'Session::Cookie';
        sub {
            my $env = shift;
            my $res = [ 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ] ];
            $app_cb->($env, $res);
            return $res;
        };
    },
    client => sub {
        my $cb = with_cookies(shift);
        my $res;

        my $called;
        $app_cb = sub {
            my ($env, $res) = @_;
            $called = ++$env->{'session.coookies'}{called};
        };
        $cb->();
        $cb->();
        is $called, 2, 'alternate session handling middleware working';
    };

done_testing;

