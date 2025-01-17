#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $cpev_mock = Test::MockModule->new('cpev');
my $ssh_mock  = Test::MockModule->new('Elevate::Blockers::SSH');

my $cpev = cpev->new;
my $ssh  = $cpev->get_blocker('SSH');

{
    note "checking _sshd_setup";

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    my $sshd_error_message = <<~'EOS';
    OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file, which will default in RHEL8 to "prohibit-password".
    Please set the 'PermitRootLogin' value in /etc/ssh/sshd_config before upgrading.
    EOS

    is $ssh->_sshd_setup() => 0, "sshd_config does not exist";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents('');
    is $ssh->_sshd_setup() => 0, "sshd_config with empty content";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Fruit=cherry
    Veggy=carrot
    EOS
    is $ssh->_sshd_setup() => 0, "sshd_config without PermitRootLogin option";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Key=value
    PermitRootLogin=yes
    EOS
    is $ssh->_sshd_setup() => 1, "sshd_config with PermitRootLogin=yes - multilines";

    $mock_sshd_cfg->contents(q[PermitRootLogin=no]);
    is $ssh->_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin no]);
    is $ssh->_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin  =  no]);
    is $ssh->_sshd_setup() => 1, "sshd_config with PermitRootLogin  =  no";

    $mock_sshd_cfg->contents(q[#PermitRootLogin=no]);
    is $ssh->_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=no";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents(q[#PermitRootLogin=yes]);
    is $ssh->_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=yes";
    message_seen( 'ERROR', $sshd_error_message );
}

{
    note "sshd setup check";

    $ssh_mock->redefine( '_sshd_setup' => 0 );
    is(
        $ssh->_blocker_invalid_ssh_config(),
        {
            id  => q[Elevate::Blockers::SSH::_blocker_invalid_ssh_config],
            msg => 'Issue with sshd configuration',
        },
        q{Block if sshd is not explicitly configured.}
    );

    $ssh_mock->redefine( '_sshd_setup' => 1 );
    is( $ssh->_blocker_invalid_ssh_config, 0, "no blocker if _sshd_setup is ok" );
    $ssh_mock->unmock('_sshd_setup');
}

done_testing();
