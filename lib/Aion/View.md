# NAME

Aion::View — объектно-ориентированный фреймворк вроде Moose и Moo

# SYNOPSIS

```perl
# Пакет Calculator может складывать, вычитать, делить и умножать два числа
package Calculator {
    use common::sense;
    use Aion::View;

    # Внедряет атрибуты у has - in, from, конструктор new_from_request
    with 'Aion::Role::Controller';

    has a  => (is => 'ro+', isa => Num, in => 'path');
    has op => (is => 'ro+', isa => MatchStr[qr![-+*/]!], in => 'query');
    has b  => (is => 'ro+', isa => Num, in => 'path');

#@method GET /calculate/{a}/{b} „Вычисляет выражение”
    sub get {
        my ($self) = @_;
        eval join "", $self->a, $self->op, $self->b
    }
}

# Создаём простой объект:
Calculator->new(a=>1, op=>"+", b=>2)->get # => 3

# Через создание объекта запроса:
use Aion::Request;
my $request = Aion::Request->new(SLUG => {a => 1, b => 2}, QUERY_STRING => "op=%2B");
my $calc = Calculator->new_from_request($request);

$calc->get  # => 3

$calc       # --> Calculator->new(a=>1, op=>"+", b=>2)

```

# DESCRIPTION



# LICENSE

© Yaroslav O. Kosmina
2022
