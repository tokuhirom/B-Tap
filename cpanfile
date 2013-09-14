requires 'perl', '5.008001';
requires 'B::Generate';
requires 'parent';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'B::Tools';
};

