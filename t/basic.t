use strict;
use warnings;
use Test::More 0.88;

use Plack::Middleware::NamedSession;
use Plack::Test;
use Plack::Builder;
use HTTP::Cookies;

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
        my $cb = shift;
        my $req;
        my $res;
        my $jar = HTTP::Cookies->new;

        $app_cb = sub {
            my ($env, $res) = @_;
            ok ! (exists $env->{'psgix.session'}), 'standard session location not created';
            my $called = ++$env->{'session.coookies'}{called};
            $res->[2] = [$called];
        };

        $req = HTTP::Request->new(GET => 'http://localhost/');
        $res = $cb->($req);
        $jar->extract_cookies($res);

        $req = HTTP::Request->new(GET => 'http://localhost/');
        $jar->add_cookie_header($req);
        $res = $cb->($req);
        is $res->decoded_content, 2, 'session data maintained';
    };

done_testing;

