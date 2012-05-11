#!/usr/bin/env ruby

# Copyright 2011 Welliton de Souza
#
# Este programa é um software livre; você pode redistribui-lo e/ou 
# modifica-lo dentro dos termos da Licença Pública Geral GNU como 
# publicada pela Fundação do Software Livre (FSF); na versão 2 da 
# Licença, ou (na sua opnião) qualquer versão.
#
# Este programa é distribuido na esperança que possa ser  util, 
# mas SEM NENHUMA GARANTIA; sem uma garantia implicita de ADEQUAÇÂO a qualquer
# MERCADO ou APLICAÇÃO EM PARTICULAR. Veja a
# Licença Pública Geral GNU para maiores detalhes.
#
# Você deve ter recebido uma cópia da Licença Pública Geral GNU
# junto com este programa, se não, escreva para a Fundação do Software
# Livre(FSF) Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# Tratar os argumentos.
args = ARGV.join(';')
if args =~ /-h|--help/i
  $stderr.puts DATA.read
  exit
end
if args =~ /-t|--table/i
  @show_table = true
end
if args =~ /-d|--debug/
  @show_debug = true
end
if args =~ /-m=(\d+)/
  @m = $1? $1.to_f : -99999
  @m *= -1 if @m > 0
else
  @m = -99999
end

# Rotina para imprimir tabela.
def print_table(message)
  return unless @show_table
  puts message
  @nomes_col.each do |nome|
    printf "%s\t", nome
  end
  puts
  count = 0
  @table.each do |row|
    printf "%s\t", @nomes_row[count]
    row.each do |col|
      printf "%.2f\t", col
    end
    puts
    count += 1
  end
  puts
end

#Rotina para imprimir mensagens de Debug.
def print_debug(message)
  return unless @show_debug
  $stderr.puts "\e[37m#{message}\e[0m"
end

# Ler entrada padrão.
input = $stdin.read

# Iterar por cada problema encontrado.
input.scan /^\((\w+)\)\s*Z\s*=\s*(.+)\n([^(]+)/ do
  # Extrair tipo, função objetiva e restrições do problema.
  type = $1
  obj_func = $2
  rest_vars = $3
  
  print_debug message = <<EOS
Tipo: #{type}
Função objetiva: #{obj_func}
Variáveis de restrições:
#{rest_vars.gsub(/\n\n/, "\n").chomp}
EOS
  
  # Criar tabela
  @table = []
  @table[0] = []
  @table[0][0] = 0
  
  # Criar vetor para armazenar nomes das variaveis.
  @nomes_col = []
  @nomes_col << ''
  @nomes_col << ''
  @nomes_row = []
  @nomes_row << ''
  
  # Da função objetiva, extrair as variáveis de decisão e respectivos 
  # coeficiente.
  row = 0
  col = 1
  obj_func.scan /([+-])?\s*([\d.]+)?(\w+\d+)/ do
    op = $1
    coef = $2? $2.to_f : 1
    var = $3
    
    coef *= -1 if type =~ /min/i
    @table[row][col] = coef
    @nomes_col << var
    
    print_debug message = <<EOS
Variável: #{var}
Coeficiente: #{coef}
Operador: #{op}
EOS
  
    col += 1
  end
  
  # Quantidade de variáveis encontradas.
  amount = @table[0].size - 1
  
  # Criar vetor auxiliar para os totais das funções de restrição.
  total = []
  total[0] = 0
  
  # Das restrições, extrair os coeficientes das variáveis de decisão, 
  # respectivo total e acrescentar variáveis de folga.
  row = 1
  rest_vars.each_line do |line|
    next if line.chomp.empty?
    col = 1
    @table[row] = []
    @table[row][0] = 0
    # Coeficientes.
    line.scan /([+-])?\s*([\d.]+)?(\w+\d+)/ do
      op = $1
      coef = $2? $2.to_f : 1
      var = $3
      
      coef *= -1 if type =~ /-/
      @table[row][col] = coef
      
      print_debug message = <<EOS
Variável: #{var}
Coeficiente: #{coef}
Operador: #{op}
EOS

      col += 1
    end
    # Total.
    total[row] = line[/\d+\s*$/].to_f
    
    print_debug message = <<EOS
Total: #{total[row]}
EOS

    # Variáveis de folga.
    op = line[/[=<>]+/]
    col = @table[0].size
    if op =~ /<=/
      @table[0][col] = 0
      @table[row][col] = 1
      @nomes_col << "f#{col}"
      @nomes_row << "f#{col}"
      
      print_debug message = <<EOS
Variável de folga adicionada.
EOS

    elsif op =~ />=/
      @table[0][col] = 0
      @table[row][col] = -1
      @nomes_col << "e#{col}"
      
      @table[0][col+1] = @m
      @table[row][col+1] = 1
      @table[row][0] = @m
      @nomes_col << "a#{col+1}"
      @nomes_row << "a#{col+1}"
      
      print_debug message = <<EOS
Variável de excesso e virtual adicionadas.
EOS
      
    else
      @table[0][col] = @m
      @table[row][col] = 1
      @table[row][0] = @m
      @nomes_col << "a#{col}"
      @nomes_row << "a#{col}"
      
      print_debug message = <<EOS
Variável veirtual adicionada.   
EOS

    end
    
    @table.each do |tmp_row|
      tmp_row << 0 unless tmp_row[col]
    end
    
    row += 1
  end
  
  # Quantidade de restrições.
  amount_rest = row - 1
  
  # Converter valores nulos em 0.
  row = amount - 1
  while row < @table.size do
    col = 1
    while col < @table[0].size do
      @table[row][col] = 0 unless @table[row][col]
      col += 1
    end
    row += 1
  end
  
  # Adicionar os totais a tabela.
  @nomes_col << 'Total'
  count = 0
  @table.each do |row|
    row << total[count]
    count += 1
  end
  
  # Preparar linha da tabela para armezenar os resultados (Zj - Cj)
  @nomes_row << '(Zj-Cj)'
  size = @table.size
  @table[size] = []
  col = 0
  while col < @table[0].size do
    @table[size][col] = 0
    col += 1
  end
  
  print_table "Tabela inicial"
  # Iterar até que encontre a solução ótima.
  iteracao = 1
  continue = true
  while continue
    
    print_debug message = <<EOS
Iteração #{iteracao}
EOS

    # Iterar pelas colunas (variáveis).
    col = 1
    while col < @table[0].size do
      total = 0
      # Iterar pelas linhas (restrições) e calcular o total.
      row = 1
      while row < size do
        total += @table[row][0] * @table[row][col]
        row += 1
      end
      # Subtrair o total pelo coeficiente da variável atual.
      @table[size][col] = total - @table[0][col]
      col += 1
    end
    
    # Encontrar coluna de trabalho.
    min = @table[size][1]
    min_col = 1
    count = 2
    while count < @table[0].size() - 1  do
      if @table[size][count] < min
        min = @table[size][count]
        min_col = count
      end
      count += 1
    end

    print_debug message = <<EOS
Coluna de trabalho encontrada: @table[#{size}][#{min_col}]
Valor: #{@table[size][min_col]}
EOS

    # Verifica se deve continuar.
    if @table[size][min_col] >= 0
      
      print_debug message = <<EOS
Valor da coluna de trabalho maior ou igual a 0, parar.
EOS
      
      continue = false
      print_table "Tabela final"
      # Imprime o resultado.
      row = 1
      col = @table[0].size - 1
      while row < @table.size - 1 do
        print "#{@nomes_row[row]}="
        printf "%.2f, ", @table[row][col]
        row += 1
      end
      printf "Z=%.2f\n", @table[row][col]
      next
    end
    
    print_debug message = <<EOS
Valor da coluna de trabalho menor que 0, continuar.
EOS
  
    # Calcular theta
    theta = []
    row =  1
    total_index = @table[0].size() -1
    while row < @table.size() - 1 do
      if @table[row][min_col] >= 0
        theta << @table[row][total_index] / @table[row][min_col]
      else
        theta << @m * -1
      end
      row += 1
    end
  
    # Encontrar linha pivô.
    min = theta[0]
    min_row = 1
    count = 0
    while count < theta.size do
      if theta[count] < min
        min = theta[count]
        min_row = count + 1
      end
      count += 1
    end
    
    # Verificar se problema não tem solução
    if @table[min_row][min_col] < 0
      print_table "Ultima tabela."

    print_debug message = <<EOS
Valor do elemento pivot menor que 0, parar.
EOS

      puts 0
      break
    end
  
    print_debug message = <<EOS
Linha e elemento pivô encontrados: @table[#{min_row}][#{min_col}]
Valor: #{@table[min_row][min_col]}
EOS

    # Mover variável para a base.
    @table[min_row][0] = @table[0][min_col]
    @nomes_row[min_row] = @nomes_col[min_col + 1]

    print_debug message = <<EOS
Variável movida para a base: @table[#{min_row}][0]
Valor: #{theta[min_row]}
EOS

    
    # Copiar coluna de trabalho e linha pivo.
    work_col = []
    row = 0
    while row < @table.size
      work_col << @table[row][min_col]
      row += 1
    end
    pivot_row = []
    col = 0
    while col < @table[0].size
      pivot_row << @table[min_row][col]
      col += 1
    end
  
    # Atualizar tabela.
    pivot = @table[min_row][min_col]
    row = 1
    while row < @table.size() - 1 do
      col = 1
      while col < @table[0].size() do
        if row.eql? min_row
          @table[row][col] = @table[row][col] / pivot
        else
          @table[row][col] = @table[row][col] - (pivot_row[col] * work_col[row]) / pivot
        end
        col += 1
      end
      row += 1
    end
    
    print_debug message = <<EOS
Tabela atualizada.
EOS
    
    print_table "Tabela\t Iteração #{iteracao}"
    iteracao += 1
  end
end
__END__
Uso:
% ruby simplex_table.rb < arquivo.txt
Argumentos:
-t|--table Imprime a tabela em cada etapa.
-d|--debug Imprime mensagens de Debug (saida de erro).
-m=VALOR   Configura o valor de M para VALOR (o padrão é 99999).
Observações:
  Para valores decimais utilize ponto ao invés de virgula (ex: 4.2x1).
  Variáveis são identificadas por letras + numeros (ex: x1 e recurso42).
  Todas as restrições devem ter a mesma quantidade de variáveis que a função objetiva (ex: mude x2 >= 42 para 0x1 + x2 >= 42).

A language that doesn't affect the way you think about programming, is not worth knowing. - Alan J. Perlis
