use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'ShinyCMS' }
BEGIN { use_ok 'ShinyCMS::Controller::Admin::Pages' }

ok( request('/admin/pages')->is_success, 'Request should succeed' );
done_testing();
