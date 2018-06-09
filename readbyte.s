.extern fread, fwrite


.data
  c: .byte 0

.text
       .globl  readbyte
# Navn:        readbyte
# Synopsis:    Leser en byte fra en binærfil.
# C-signatur:  int readbyte (FILE *f)
# Registre:


readbyte:
       pushl  %ebp            # Standard funksjonsstart
       movl    %esp,%ebp       #

       # legg parametrene på stacken reverse order
       pushl   8(%ebp)                  # file
       pushl   $1                       # size
       pushl   $1                       # nmemb
       leal    c, %edx                  # create char
       pushl   %edx                     # char

       # bruk instruksjonen call.
       call    fread

       # fjern parametrene fra stacken
       cmpl     $0, %eax                  # Sammenlign outputen til fread
       jbe      eof_1                     # hopp til end of file om fread return -1
       movl     c, %eax                   # bevege c til eax
       jmp      rb_x

eof_1:
        movl    $-1, %eax                 # sett output til -1, hopp videre til eof_1
rb_x:
        addl     $16, %esp                 #fjern parametrene fra stacken
        movl    %esp, %ebp
        popl    %ebp                       # Standard
        ret                                # retur.

       .globl  readutf8char
# Navn:        readutf8char
# Synopsis:    Leser et Unicode-tegn fra en binærfil.
# C-signatur:  long readutf8char (FILE *f)
# Registre:


readutf8char:
	pushl	  %ebp			    # Standard funksjonsstart
	movl	  %esp,%ebp		  #
	pushl   8(%ebp) 			# Putt filen på stacken
	call    readbyte 			# int readbyte (FILE *f)
                        # kaller jeg riktig under? Ja, I henhold til utf8
  addl  $4, %esp
  movl  %eax, %edx
  shrl  $4, %edx        # check first 4 LSB
  cmpb  $0xc, %dl
  jl    ru8_x
  cmpb  $0xe, %dl
  je    ru8_3
  cmpb  $0xf, %dl
  je    ru8_4

ru8_2: # 110xxxxx 10xxxxxx
  andl  $0x1F, %eax  # Null ut alle bit utenom de siste fem bitene
  call  readfollowbyte
  jmp   ru8_x

ru8_3: # 1110xxxx 10xxxxxx 10xxxxxx
  andl  $0xF, %eax
  call  readfollowbyte
  call  readfollowbyte
  jmp   ru8_x

ru8_4: # 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
  andl  $0xF, %eax
  call  readfollowbyte
  call  readfollowbyte
  call  readfollowbyte
  jmp   ru8_x


readfollowbyte:
  sall  $6, %eax         # setter plass til neste følgebitt
  movl  %eax, %ebx

  pushl 8(%ebp)          # sender ved fil som param til readbyte
  call  readbyte
  addl  $4, %esp

  andl  $0x3F, %eax      # fjern prefix i 10xxxxxx
  orl  %ebx, %eax        # setter den behandlede verdien inn i %edx
  ret

ru8_x:
  movl %esp, %ebp
  popl %ebp
  ret


       .globl  writebyte
# Navn:        writebyte
# Synopsis:    Skriver en byte til en binærfil.
# C-signatur:  void writebyte (FILE *f, unsigned char b)
# Registre:

writebyte:
       pushl   %ebp            # Standard funksjonsstart
       movl    %esp,%ebp       #

       # legg parametrene på stacken reverse order
       pushl   8(%ebp)                  # file
       pushl   $1                       # size
       pushl   $1                       # nmemb
       leal    12(%ebp), %eax           # adresse til byte
       pushl   %eax                     # byte adresse

       # bruk instruksjonen call
       call    fwrite

       # fjern argumentene fra stacken
       addl $16, %esp

       # standard returmetode
       movl %esp, %ebp
       popl %ebp
       ret

       .globl  writeutf8char
# Navn:        writeutf8char
# Synopsis:    Skriver et tegn kodet som UTF-8 til en binærfil.
# C-signatur:  void writeutf8char (FILE *f, unsigned long u)
# Registre:


writeutf8char:
	pushl	%ebp			          # Standard funksjonsstart
	movl	%esp, %ebp 	        #
  movl  12(%ebp), %eax      # Flytt symbolet til eax
  cmpl  $0x7F, %eax
  jbe   writeonebyte
  cmpl  $0x07FF, %eax
  jbe   writetwobyte
  cmpl  $0xFFFF, %eax
  jbe   writethreebyte
  cmpl  $0x1FFFFF, %eax
  jbe   writefourbyte
  jmp   wu8_x

onebyteUtf8write:
  pushl  %eax
  pushl  8(%ebp)
  call   writebyte
  popl   8(%ebp)
  popl   %eax
  ret

writeonebyte:
  call    onebyteUtf8write
  jmp     wu8_x

writetwobyte:
	shrl     $6, %eax 			    # Flytt 6 bit til høyre
	andl     $31, %eax 		      # Null ut de 3 MSB
	orl      $192, %eax 		    # get 110xxxxx
  call     onebyteUtf8write
	movl     $1,%ebx	          # set counter used in writefollowbyte
  jmp      writefollowbyte

writethreebyte:
  shrl    $12, %eax            # move to right 6-bit*2
  andl    $15, %eax 		       # Null ut de 4 MSB
  orl     $224, %eax           # get 1110xxxx
  call    onebyteUtf8write
	movl    $2, %ebx	           # set counter used in writefollowbyte
  jmp     writefollowbyte


writefourbyte:
  shrl    $18, %eax           # move to right 6-bit*3
  andl    $7, %eax            # Null ut de 5 MSB
  orl     $240, %eax          # get 110xxxxx
  call    onebyteUtf8write
	movl    $3, %ebx	          # set counter used in writefollowbyte
  jmp     writefollowbyte

writefollowbyte:
	decl   %ebx			             # decrease counter
	movl   $6, %eax              # move 6 bit to %eax
	imull  %ebx                  # multiply this with counter
	movl   %eax, %ecx            # move the value to %ecx
  movl   12(%ebp), %eax        # move unicode to %eax
  shrl   %cl, %eax             # get the six byte I want to write
  andl   $63, %eax             # add this with 111111 to get only the six byte
  orl    $128, %eax            # put on prefix 10, such that we get 10xxxxxx
	call   onebyteUtf8write      # write the one byte part of unicode
	cmp    $0, %ebx		           # jump if counter is not 0
  jnz    writefollowbyte 		   #

wu8_x:
  movl    %ebp, %esp           # Standard returmetode
  popl    %ebp                 #
  ret
