use strict; use warnings; use utf8; use open qw/:std :utf8/; use Test::More 0.98; # # NAME
# 
# Aion::View — объектно-ориентированный фреймворк вроде Moose и Moo
# 
# # SYNOPSIS
# 

subtest 'SYNOPSIS' => sub { 	use common::sense;
	
	# Пакет Calculator может складывать, вычитать, делить и умножать два числа
	package Calculator {
	    use common::sense;
	    use Aion::View;
	
	    # Внедряет атрибуты у has - in, from, конструктор new_from_request
	    with 'Aion::Role::Controller';
	
	    has a  => (is => 'ro+', isa => Num, in => 'path');
	    has op => (is => 'ro+', isa => MatchStr[qr!^[-+*/]$!], in => 'query');
	    has b  => (is => 'ro+', isa => Num, in => 'path');
	
	#@method GET /calculate/{a}/{b} „Вычисляет выражение”
	    sub get {
	        my ($self) = @_;
	        eval join "", $self->a, $self->op, $self->b
	    }
	}
	
	# Создаём простой объект:
	is scalar do {Calculator->new(a=>1, op=>"+", b=>2)->get}, "3", 'Calculator->new(a=>1, op=>"+", b=>2)->get # => 3';
	
	# Через создание объекта запроса:
	use Aion::Request;
	my $request = Aion::Request->new(SLUG => {a => 5, b => 6}, QUERY_STRING => "op=%2B");
	my $calc = Calculator->new_from_request($request);
	
	is scalar do {$calc->get}, "11", '$calc->get  # => 11';
	
	is_deeply scalar do {$calc}, scalar do {Calculator->new(a=>1, op=>"+", b=>2)}, '$calc       # --> Calculator->new(a=>1, op=>"+", b=>2)';
	

# 
# # DESCRIPTION
# 
# 
# 
# # LICENSE
# 
# © Yaroslav O. Kosmina
# 2022

	done_testing;
};

done_testing;
