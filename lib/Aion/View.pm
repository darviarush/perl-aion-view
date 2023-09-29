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
use Aion::Spirit;
use Text::Trim qw/trim ltrim rtrim/;
use List::Util qw/all any first reduce pairmap pairgrep/;

with qw/Aion::Action Aion::Sige Aion::Run/;

1" or die;

}

1;