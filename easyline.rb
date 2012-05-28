# Readline libraries suck ass, this doesn't. There, I said it.
# I wrote this to be awesomer then the rest.

class EasyLine
  attr_accessor :complete

  def initialize
    @doStop = false
    if File.exists? ".history"
      fh = File.open(".history", File::RDONLY) 
      @history = fh.readlines.map { | x | x.strip! }

      @history << ''
    else 
      @history = ['']
    end
    @historyFile = File.open(".history", File::WRONLY|File::APPEND|File::CREAT) 
    @p = @history.length - 1
    @current = ''
    @column = 0
    @prompt = '>'
    @old = `stty -g`.chomp
    on
  end

  def on
    options = [
      '-brkint',
      '-ctlecho',
      '-echo',
      '-echok',
      '-icanon', 
      '-imaxbel', 
      '-isig', 
      '-ixany', 
      '-ixoff ', 
      '-ixon', 
      '-parmrk',
      '-igncr',
      '-ignbrk',
      '-icrnl', 
      'echonl',
      'inlcr',
      'onlret',
      'onlcr',
      'opost',
 #     '-xcase min 1 time 0'
    ]

    `stty #{options.join(' ')}`
  end

  def stop; @doStop = true; end
  def off; system('stty', @old); end

  def draw
    printf "\r\033[K#{@prompt}#{@history[-1]}"
    cursor = (@history[-1].length - @column)
    printf "\033[#{cursor}D" if cursor > 0 
    $stdout.flush
  end

  def debug
    off
    puts
    i = 0
    @history.each { | str |

      if (@p == i) 
        printf " * "
      else 
        printf "   "
      end

      printf "%s\n", str

      i += 1
    }
    on
  end

  def each
    docapture = 0
    captured = ''
    loop {
      char = STDIN.getc
      if docapture > 0
        captured << char
        docapture -= 1
        char = captured
      end
      if char.class == Fixnum and [char].pack('c') =~ /[[:print:]]/
        @history[-1].insert(@column, [char].pack('c'))
        @column += 1
        @current = @history[-1]
      else
        case char
        when "[A", 16 # CTRL-P (UP)
          @p -= 1 if @p > 0
          @history[-1] = @history[@p].clone
          @column = @history[-1].length

        when "[B", 14 # CTRL-N (DOWN)
          @p += 1 if @history.length - 1 > @p
          if @history.length - 1 == @p
            @history[-1] = @current
          else
            @history[-1] = @history[@p].clone
          end
          @column = @history[-1].length

        when "[H" # (HOME)
          @column = 0

        when "[F" # (END)
          @column = @history[-1].length

        when "[D" # (LEFT)
          @column = [@column - 1, 0].max

        when "[C" # (RIGHT)
          @column = [@column + 1, @history[-1].length].min

        when 13
          puts "\r"
          @current = ''
          off
          command = @history[-1]
          if @history[-1] != ''
            @p = @history.length
            @historyFile << "#{@history[-1]}\n"
            @history << '' 
            @column = @history[-1].length
          else
            command = ' '
          end
          command.split(';').each { | part | 
            yield part
          }
          on

          if @doStop
            puts "\r"
            return
          end

        when 27
          docapture = 2
          captured = ''

        when 3
          off
          puts "\r"
          Process.kill("INT", $$)
          exit

        when 9 # (tab)
          off
          unless @complete.nil?
            result = @complete.call(@history[-1])
            unless result.nil?
              if(result.length == 1) 
                breakdown = @history[-1].split(' ')
                breakdown.pop
                breakdown.push(result[0].clone + ' ')
                @history[-1] = breakdown.join(' ').gsub(/\s+$/, ' ')
              else
                maxwidth = 0
                result.reject! { | x | x.class != String }

                result.map! { | which | which.split(' ').pop }

                result.each { | which |
                  maxwidth = which.length unless which.length < maxwidth
                }
                maxwidth += 2
                totalwidth = 0
                puts "\r"
                result.each { | which |
                  eval "printf \"%-#{maxwidth}s\", which"
                  totalwidth += maxwidth
                  if totalwidth > 80
                    puts "\r"
                    totalwidth = 0
                  end
                }
                puts "\r"
              end
            end
          end
          on
          @column = @history[-1].length
          
        when 1 # CTRL-A
        when 12 # CTRL-L
          `reset`
          on

        when 23 # CTRL-W
          start = [@column - 1, 0].max
          while start > 0 and @history[-1][start] > 32
            start -= 1 
          end
          @history[-1].slice!(start, @column - start)
          @column = start

        when 21 # CTRL-U
          @history[-1] = ''
          @current = @history[-1]
          @column = @history[-1].length

        when 127 # Backspace
          @column = [@column - 1, 0].max
          @history[-1].slice!(@column,1)
          @current = @history[-1]

        else
          # puts "<<#{char}>>"

        end
      end

      draw
    }
  end

  # This can be called, dynamically. Yeah Imagine that !
  def set_prompt(text)
    @prompt = text
    draw
  end
end
