# MQL + IA
> Robôs de negociação automatizada
 
## Descrição
> As tecnologias que estão sendo usadas são MQL e Python (para aplicação de conceitos de IA)
 
**Estratégias**
 - [Estratégia 1](#estrat%C3%A9gia-1-melhores-resultados-em-movimentos-de-tend%C3%AAncia)
 - [Estratégia 2](#scalper-2-melhores-resultados-em-lateraliza%C3%A7%C3%A3o)
## Estratégia 1: Melhores resultados em movimentos de tendência
## Estratégia 2: Scalper - Melhores resultados em lateralização
Periodicidade 
5 minutos

> Indicadores:
>     EMA11   → Média móvel exponencial de 11 períodos
 >    RSI     → Índice de força relativa de 2 períodos
> 
> Entrada:
>  Condição
>  Se for a primeira operação
>     Se RSI maior que 90
>        Venda
>     Se RSI é menor que 10
>        Compra
>  Senão
>     Se RSI < 10
>        Se a penúltima operação foi uma venda
>           Se C1 > C2, Compra
>     Se RSI > 90 
>       Se a penúltima operação foi uma compra
>           Se C1 < C2, Venda
> 
>  C0 ← Candle atual
>  C1 ← Último preço de fechamento
>  C2 ← Penúltimo preço de fechamento


Preço de entrada 
Preço no momento de que houve o sinal do RSI
Stop
Aberto (Sugestão: 500 pontos)

Saída:

Condição
Preço corta EMA11 e passou o período de 1 candle 
Preço de saída

