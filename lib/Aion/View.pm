package Aion::View;
# ООП вроде Moose - так же добавляет 
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.01";

BEGIN {
	vec( ${^WARNING_BITS}, $warnings::Offsets{'recursion'}, 1 ) = 1;
}

# Инициализируем рендом-генератор ($$ - текущий процесс)
# Time::HiRes::time() ?
srand(time()+$$);

use DDP {
	colored => 1,
	class => {
		expand => "all",
		inherited => "all",
		show_reftype => 1,
	},
	deparse => 1,
	show_unicode => 1,
	show_readonly => 1,
	print_escapes => 1,
	#show_refcount => 1,
	#show_memsize => 1,
	caller_info => 1,
	output => 'stdout',
};

# Импорт
sub import {
	my $pkg = caller;

	eval "package $pkg;
use common::sense;
use Aion;
use Aion::Carp;
use Aion::Action::Util qw/msg trace/;
use Aion::Fs;
use Aion::Format;
use Text::Trim qw/trim ltrim rtrim/;
use List::Util qw/all any first reduce pairmap pairgrep/;

*np = \\&DDP::np;
*p = \\&DDP::p;
*ASSERT = \\&Aion::View::ASSERT;
*firstidx = \\&Aion::View::firstidx;
*firstres = \\&Aion::View::firstres;

with qw/Aion::Action Aion::Sige Aion::Run/;

1" or die;

}

# assert
sub ASSERT {
	die "ASSERT: ".(ref $_[1]? $_[1]->(): $_[1])."\n" if !$_[0];
}

# Ищет в списке первое совпадение и возвращает индекс найденного элемента
sub firstidx (&@) {
	my $s = shift;

	my $i = 0;
	for(@_) {
		return $i if $s->();
		$i++;
	}
	return undef;
}

# Ищет в списке первый положительный разультат функции
sub firstres (&@) {
	my $s = shift;

	for(@_) {
		my $x = $s->();
		return $x if $x;
	}
	return undef;
}

1;