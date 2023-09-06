requires 'perl', '5.008001';

on 'test' => sub {
    requires 'Test::More', '0.98';
	requires 'Liveman',
		git => 'https://github.com/darviarush/perl-liveman.git',
		ref => 'master',
	;
};

requires 'Aion',
	git => 'https://github.com/darviarush/perl-aion.git',
	ref => 'master',
;

requires 'Aion::Carp',
	git => 'https://github.com/darviarush/perl-aion-carp.git',
	ref => 'master',
;