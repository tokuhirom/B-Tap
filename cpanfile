requires 'perl', '5.022000';
requires 'parent';
requires 'B::Tools';
requires 'Try::Tiny';
requires 'B::Deparse';
requires 'B';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

