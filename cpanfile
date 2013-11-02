requires 'perl', '5.014000';
requires 'parent';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'B::Tools';
    requires 'B::Deparse';
    requires 'B';
};

