# -*- perl -*-

use Test::More;

use File::Spec;
my $testdir = (File::Spec->splitpath($0))[1];

BEGIN {
    use_ok('HC::CredentialStore');
}

# With no filename, it should fail
is(HC::CredentialStore->new(),undef);

# With a non-existant filename, it should fail
is(HC::CredentialStore->new(File::Spec->catfile($testdir,'CredentialStore.enofile')),undef);

# can load the test file as expected
my $cred = new_ok(HC::CredentialStore =>[
    File::Spec->catfile($testdir,'CredentialStore.test1')
]);

is($cred->lookup_username('testservice'),'testuser');
is($cred->lookup_password('testservice'),'testpass');

is(($cred->lookup('testservice2'))[0],'testuser');
is(($cred->lookup('testservice2'))[1],'testpass');

done_testing();

