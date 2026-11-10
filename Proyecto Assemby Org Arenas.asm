; =========================================================
; proyecto assembly: conversor de bases numericas
; espol - organizacion de computadores
; Juan Pablo Arenas Tituanha
; =========================================================

.model small
.stack 100h

.data
    msg_menu        db 13,10,'=== CONVERSOR DE BASES NUMERICAS ===',13,10
                     db '1. Decimal    -> Binario',13,10
                     db '2. Decimal    -> Hexadecimal',13,10
                     db '3. Binario    -> Decimal',13,10
                     db '4. Hexadecimal -> Decimal',13,10
                     db '5. Salir',13,10
                     db 'Seleccione una opcion: $'

    msg_opcion_inv  db 13,10,'Opcion invalida.',13,10,'$'
    msg_pedir_dec   db 13,10,'Ingrese numero decimal (0-255): $'
    msg_pedir_bin   db 13,10,'Ingrese numero binario (max 8 bits): $'
    msg_pedir_hex   db 13,10,'Ingrese numero hexadecimal (0-FF): $'
    msg_error_char  db 13,10,'Entrada invalida. Intente de nuevo.',13,10,'$'
    msg_res_bin     db 13,10,'Resultado en BINARIO: $'
    msg_res_hex     db 13,10,'Resultado en HEXADECIMAL: $'
    msg_res_dec     db 13,10,'Resultado en DECIMAL: $'
    msg_salir       db 13,10,'Fin del programa. Hasta luego!',13,10,'$'
    msg_continuar   db 13,10,'Presione una tecla para continuar...',13,10,'$'

    ; estructura requerida por int 21h funcion 0ah:
    ; byte0 = tamano maximo, byte1 = caracteres leidos, byte2.. = datos
    buffer_max      db 10
    buffer_len      db ?
    buffer_data     db 11 dup('$')

    modo            db 0        ; 0=decimal, 1=binario, 2=hexadecimal
    valor           dw 0        ; valor numerico resultante (0-255)
    resultado       db 12 dup('$')  ; cadena de salida ya formateada

.code
inicio:
    mov ax, @data
    mov ds, ax

    call menu_principal

    mov ah, 4ch
    int 21h

; ---------------------------------------------------------
; menu_principal
; muestra el menu de opciones, lee la seleccion del usuario
; y llama al procedimiento de conversion correspondiente.
; modifica: ax, dx
; ---------------------------------------------------------
menu_principal proc
    mostrar_menu:
        lea dx, msg_menu
        mov ah, 09h
        int 21h

        mov ah, 01h         ; leer un caracter (con eco en pantalla)
        int 21h             ; al = caracter ingresado

        cmp al, '1'
        je opcion_1
        cmp al, '2'
        je opcion_2
        cmp al, '3'
        je opcion_3
        cmp al, '4'
        je opcion_4
        cmp al, '5'
        je opcion_5

        lea dx, msg_opcion_inv
        mov ah, 09h
        int 21h
        jmp mostrar_menu

    opcion_1:
        call dec_a_bin
        jmp mostrar_menu
    opcion_2:
        call dec_a_hex
        jmp mostrar_menu
    opcion_3:
        call bin_a_dec
        jmp mostrar_menu
    opcion_4:
        call hex_a_dec
        jmp mostrar_menu
    opcion_5:
        lea dx, msg_salir
        mov ah, 09h
        int 21h
        ret
menu_principal endp

; ---------------------------------------------------------
; leer_numero
; lee una cadena con int 21h/0ah y la valida caracter a
; caracter segun el valor de modo (0=decimal,1=binario,
; 2=hexadecimal). si un caracter es invalido, muestra error
; y vuelve a pedir el dato completo.
; entrada: modo debe estar establecido antes de llamar.
; salida:  buffer_data / buffer_len contienen la cadena valida.
; modifica: ax, bx, cx, dx, si
; ---------------------------------------------------------
leer_numero proc
    reintentar_lectura:
        lea dx, buffer_max
        mov ah, 0ah
        int 21h

        xor ch, ch
        mov cl, buffer_len
        cmp cx, 0
        je entrada_invalida     ; no se ingreso nada

        lea si, buffer_data
        xor bx, bx

    validar_loop:
        cmp bx, cx
        jge validacion_ok
        mov al, [si+bx]

        cmp modo, 0
        je validar_dec
        cmp modo, 1
        je validar_bin
        jmp validar_hex

    validar_dec:
        cmp al, '0'
        jb entrada_invalida
        cmp al, '9'
        ja entrada_invalida
        jmp siguiente_car

    validar_bin:
        cmp al, '0'
        je siguiente_car
        cmp al, '1'
        je siguiente_car
        jmp entrada_invalida

    validar_hex:
        cmp al, '0'
        jb entrada_invalida
        cmp al, '9'
        jbe siguiente_car
        cmp al, 'A'
        jb entrada_invalida
        cmp al, 'F'
        jbe siguiente_car
        cmp al, 'a'
        jb entrada_invalida
        cmp al, 'f'
        ja entrada_invalida
        jmp siguiente_car

    siguiente_car:
        inc bx
        jmp validar_loop

    entrada_invalida:
        call mostrar_error
        jmp reintentar_lectura

    validacion_ok:
        ret
leer_numero endp

; ---------------------------------------------------------
; ascii_dec_a_valor
; convierte la cadena decimal en buffer_data a un numero
; en valor. formula acumulativa: valor = valor*10 + digito
; modifica: ax, bx, cx, dx, si, valor
; ---------------------------------------------------------
ascii_dec_a_valor proc
    mov valor, 0
    xor ch, ch
    mov cl, buffer_len
    lea si, buffer_data
    xor bx, bx

    loop_dec:
        cmp bx, cx
        jge fin_ascii_dec
        mov al, [si+bx]
        sub al, '0'
        xor ah, ah

        push ax
        mov ax, valor
        mov dx, 10
        mul dx              ; valor = valor * 10
        mov valor, ax
        pop ax
        add valor, ax       ; valor = valor + digito

        inc bx
        jmp loop_dec

    fin_ascii_dec:
        ret
ascii_dec_a_valor endp

; ---------------------------------------------------------
; dec_a_bin
; pide un numero decimal (0-255) y lo convierte a su
; representacion binaria de 8 bits usando shr bit a bit.
; modifica: ax, bx, cx, dx, si, valor, resultado
; ---------------------------------------------------------
dec_a_bin proc
    mov modo, 0

    repetir_dec_bin:
        lea dx, msg_pedir_dec
        mov ah, 09h
        int 21h

        call leer_numero
        call ascii_dec_a_valor

        cmp valor, 255
        ja repetir_dec_bin_error
        jmp rango_ok_bin

    repetir_dec_bin_error:
        call mostrar_error
        jmp repetir_dec_bin

    rango_ok_bin:
        mov ax, valor
        mov cx, 8
        lea si, resultado
        add si, 7            ; se escribe de derecha (lsb) a izquierda

    bit_loop:
        mov bx, ax
        and bx, 1            ; extrae el bit menos significativo
        add bl, '0'
        mov [si], bl
        dec si
        shr ax, 1
        loop bit_loop

        mov byte ptr [resultado+8], '$'

        lea dx, msg_res_bin
        mov ah, 09h
        int 21h
        call mostrar_resultado
        ret
dec_a_bin endp

; ---------------------------------------------------------
; dec_a_hex
; pide un numero decimal (0-255) y lo convierte a
; hexadecimal usando div entre 16.
; modifica: ax, bx, cx, dx, valor, resultado
; ---------------------------------------------------------
dec_a_hex proc
    mov modo, 0

    repetir_dec_hex:
        lea dx, msg_pedir_dec
        mov ah, 09h
        int 21h

        call leer_numero
        call ascii_dec_a_valor

        cmp valor, 255
        ja repetir_dec_hex_error
        jmp rango_ok_hex

    repetir_dec_hex_error:
        call mostrar_error
        jmp repetir_dec_hex

    rango_ok_hex:
        mov ax, valor
        mov bx, 16
        xor dx, dx
        div bx               ; al = digito alto, dx = digito bajo
        mov cx, dx

        cmp al, 9
        jbe digito_alto_num
        add al, 7            ; ajuste ascii para a-f
    digito_alto_num:
        add al, '0'
        mov resultado, al

        mov al, cl
        cmp al, 9
        jbe digito_bajo_num
        add al, 7
    digito_bajo_num:
        add al, '0'
        mov resultado+1, al
        mov byte ptr resultado+2, '$'

        lea dx, msg_res_hex
        mov ah, 09h
        int 21h
        call mostrar_resultado
        ret
dec_a_hex endp

; ---------------------------------------------------------
; bin_a_dec
; pide una cadena binaria (hasta 8 bits) y calcula su valor
; decimal equivalente: valor = valor*2 + bit
; modifica: ax, bx, cx, dx, si, valor
; ---------------------------------------------------------
bin_a_dec proc
    mov modo, 1

    lea dx, msg_pedir_bin
    mov ah, 09h
    int 21h

    call leer_numero

    mov valor, 0
    xor ch, ch
    mov cl, buffer_len
    lea si, buffer_data
    xor bx, bx

    loop_bin:
        cmp bx, cx
        jge fin_bin
        mov al, [si+bx]
        sub al, '0'
        xor ah, ah

        push ax
        mov ax, valor
        mov dx, 2
        mul dx               ; valor = valor * 2
        mov valor, ax
        pop ax
        add valor, ax        ; valor = valor + bit

        inc bx
        jmp loop_bin

    fin_bin:
        call valor_a_cadena_dec
        lea dx, msg_res_dec
        mov ah, 09h
        int 21h
        call mostrar_resultado
        ret
bin_a_dec endp

; ---------------------------------------------------------
; hex_a_dec
; pide una cadena hexadecimal y calcula su valor decimal
; equivalente: valor = valor*16 + digito
; modifica: ax, bx, cx, dx, si, valor
; ---------------------------------------------------------
hex_a_dec proc
    mov modo, 2

    lea dx, msg_pedir_hex
    mov ah, 09h
    int 21h

    call leer_numero

    mov valor, 0
    xor ch, ch
    mov cl, buffer_len
    lea si, buffer_data
    xor bx, bx

    loop_hex:
        cmp bx, cx
        jge fin_hex
        mov al, [si+bx]

        cmp al, '9'
        ja es_letra
        sub al, '0'
        jmp digito_listo
    es_letra:
        cmp al, 'F'
        ja es_minuscula
        sub al, 'A'-10       ; ajuste para a-f mayuscula
        jmp digito_listo
    es_minuscula:
        sub al, 'a'-10       ; ajuste para a-f minuscula

    digito_listo:
        xor ah, ah
        push ax
        mov ax, valor
        mov dx, 16
        mul dx               ; valor = valor * 16
        mov valor, ax
        pop ax
        add valor, ax        ; valor = valor + digito

        inc bx
        jmp loop_hex

    fin_hex:
        call valor_a_cadena_dec
        lea dx, msg_res_dec
        mov ah, 09h
        int 21h
        call mostrar_resultado
        ret
hex_a_dec endp

; ---------------------------------------------------------
; valor_a_cadena_dec
; convierte el numero en valor a su cadena decimal en
; resultado. usa div para extraer digitos por el resto y
; push/pop (la pila) para invertir su orden de aparicion.
; modifica: ax, bx, cx, dx, si
; ---------------------------------------------------------
valor_a_cadena_dec proc
    mov ax, valor
    mov bx, 10
    xor cx, cx               ; contador de digitos apilados

    cmp ax, 0
    jne extraer_digitos
    push ax                  ; caso especial: valor = 0
    inc cx
    jmp armar_cadena

    extraer_digitos:
    loop_extraer:
        cmp ax, 0
        je armar_cadena
        xor dx, dx
        div bx                ; al = cociente, dx = digito (resto)
        push dx
        inc cx
        jmp loop_extraer

    armar_cadena:
        lea si, resultado
    desapilar:
        cmp cx, 0
        je fin_armar
        pop dx
        add dl, '0'
        mov [si], dl
        inc si
        dec cx
        jmp desapilar

    fin_armar:
        mov byte ptr [si], '$'
        ret
valor_a_cadena_dec endp

; ---------------------------------------------------------
; mostrar_resultado
; imprime la cadena resultado ya formateada y pausa la
; ejecucion hasta que el usuario presione una tecla.
; modifica: ah, dx
; ---------------------------------------------------------
mostrar_resultado proc
    lea dx, resultado
    mov ah, 09h
    int 21h

    lea dx, msg_continuar
    mov ah, 09h
    int 21h

    mov ah, 01h
    int 21h
    ret
mostrar_resultado endp

; ---------------------------------------------------------
; mostrar_error
; imprime un mensaje indicando que la entrada fue invalida.
; modifica: ah, dx
; ---------------------------------------------------------
mostrar_error proc
    lea dx, msg_error_char
    mov ah, 09h
    int 21h
    ret
mostrar_error endp

end inicio