***********************************************************************
*
*  ═══════════════════════════════════════════════════════════════════
*   ABAP BEHAVIOR POOL (ABP) - ZBP_I_CALC_OPERATIONS
*  ═══════════════════════════════════════════════════════════════════
*
*  🎓 CONCEITO DIDÁTICO: O que é um Behavior Pool (ABP)?
*  ─────────────────────────────────────────────────────
*  O ABP é a classe ABAP onde implementamos a LÓGICA DE NEGÓCIO
*  do nosso Business Object (BO) RAP. Aqui ficam:
*
*  1. HANDLER CLASS (lhc_*) → Implementa Determinations, Validations,
*     Actions e Authorization. Herda de CL_ABAP_BEHAVIOR_HANDLER.
*
*  2. SAVER CLASS (lsc_*) → Implementa lógica que roda NO MOMENTO
*     DO SAVE (late numbering, additional save, cleanup).
*     Herda de CL_ABAP_BEHAVIOR_SAVER.
*
*  📌 POR QUE locals_imp.abap?
*  - No RAP, a classe global (zbp_i_calc_operations.clas.abap) é
*    apenas um "shell" vazio com ABSTRACT FINAL.
*  - Toda a lógica fica em CLASSES LOCAIS dentro de locals_imp.abap
*  - Isso é uma convenção do framework RAP (não opcional!)
*
*  📌 VARIÁVEIS IMPLÍCITAS (IMPORTING/CHANGING):
*  O framework RAP injeta automaticamente variáveis nos métodos:
*
*  - keys → Tabela com as chaves das instâncias sendo processadas
*  - failed → Estrutura onde marcamos instâncias com erro
*  - reported → Estrutura onde adicionamos mensagens (erro, info, etc)
*  - mapped → Estrutura com mapeamento de %pid → %key (late numbering)
*  - result → Tabela para retornar dados (usado em READ/action results)
*
*  📌 %tky (Transactional Key):
*  É a chave transacional que COMBINA:
*  - %key (chave real da entidade)
*  - %is_draft (flag indicando se é draft ou ativo)
*  SEMPRE use %tky ao invés de %key nos métodos RAP, pois isso
*  garante que o framework manipule corretamente drafts e ativos.
*
*  📌 EML (Entity Manipulation Language):
*  É a "linguagem" para ler/modificar instâncias do BO dentro do ABP.
*  - READ ENTITIES → lê dados da instância
*  - MODIFY ENTITIES → atualiza campos da instância
*  Usamos "IN LOCAL MODE" para ignorar autorização/feature control
*  dentro do próprio ABP (o ABP já tem permissão implícita).
*
***********************************************************************


***********************************************************************
*  ═══════════════════════════════════════════════════════════════════
*   HANDLER CLASS: lhc_operation
*  ═══════════════════════════════════════════════════════════════════
*
*  🎓 Esta classe implementa os métodos declarados no BDEF para
*     a entidade alias "Operation". Os métodos são:
*
*  1. calculateResult     → Determination on Modify
*  2. setAdminFields      → Determination on Modify (create)
*  3. validateOperands    → Validation on Save
*  4. get_global_authorizations → Authorization (stub)
*
***********************************************************************
CLASS lhc_operation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "-------------------------------------------------------------------------
    " 🎓 ASSINATURA DOS MÉTODOS:
    " No RAP, a assinatura dos métodos é GERADA pelo framework.
    " Quando você declara uma determination/validation no BDEF,
    " o ADT gera automaticamente a assinatura correta aqui.
    "
    " A convenção é:
    "   METHODS <nome> FOR <tipo> <trigger>
    "     IMPORTING keys FOR <entidade>~<nome>.
    "
    " Os parâmetros IMPORTING (keys) e CHANGING (failed, reported)
    " são IMPLÍCITOS — você não os declara, mas pode usá-los no corpo.
    "-------------------------------------------------------------------------

    METHODS calculateResult FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Operation~calculateResult.

    METHODS setAdminFields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Operation~setAdminFields.

    METHODS validateOperands FOR VALIDATE ON SAVE
      IMPORTING keys FOR Operation~validateOperands.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Operation RESULT result.

ENDCLASS.


CLASS lhc_operation IMPLEMENTATION.

  METHOD calculateResult.
    "=========================================================================
    " 🎓 DETERMINATION: calculateResult
    "=========================================================================
    "
    " QUANDO EXECUTA: Sempre que Operand1, Operator ou Operand2 mudam.
    "                 (definido no BDEF: determination calculateResult
    "                  on modify { field Operand1, Operator, Operand2; })
    "
    " O QUE FAZ: Lê os operandos, executa a operação matemática e
    "            grava o resultado no campo Result.
    "
    " FLUXO:
    " 1. READ ENTITIES → busca os valores atuais dos campos
    " 2. LOOP + SWITCH → calcula o resultado
    " 3. MODIFY ENTITIES → grava o resultado de volta na instância
    "
    " 📌 COMBINADO COM SIDE EFFECTS:
    " No BDEF declaramos:
    "   side effects { field Operand1 affects field Result; ... }
    " Isso faz o Fiori Elements chamar o backend após cada mudança
    " de operando, executando esta determination e atualizando
    " o campo Result na tela em tempo real.
    "=========================================================================

    "-------------------------------------------------------------------------
    " PASSO 1: Ler as instâncias que foram modificadas
    "
    " 📌 READ ENTITIES OF <bdef> IN LOCAL MODE
    "    - "IN LOCAL MODE" = ignora controle de autorização e feature
    "      control. Necessário porque estamos DENTRO do ABP.
    "    - ENTITY Operation = alias definido no BDEF
    "    - FIELDS ( ... ) = quais campos queremos ler
    "    - WITH CORRESPONDING #( keys ) = filtra pelas chaves que
    "      o framework passou (instâncias que foram modificadas)
    "    - RESULT DATA(lt_operations) = declara inline a tabela resultado
    "    - FAILED DATA(lt_failed) = captura eventuais falhas de leitura
    "-------------------------------------------------------------------------
    READ ENTITIES OF zi_calc_operations IN LOCAL MODE
      ENTITY Operation
        FIELDS ( Operand1 Operator Operand2 )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_operations)
        FAILED DATA(lt_failed_read)
        REPORTED DATA(lt_reported_read).

    "-------------------------------------------------------------------------
    " PASSO 2: Calcular o resultado para cada instância
    "
    " 📌 LOOP AT ... ASSIGNING FIELD-SYMBOL(<operation>)
    "    - FIELD-SYMBOL é um ponteiro (referência) para a linha
    "    - Modificar <operation> modifica diretamente lt_operations
    "    - Isso é mais performático do que copiar dados
    "
    " 📌 SWITCH #( ... )
    "    - Expressão condicional que retorna um valor baseado no caso
    "    - Substitui IF/ELSEIF aninhados de forma elegante
    "    - Cada WHEN testa o valor do operador e executa a operação
    "    - ELSE trata operadores inválidos
    "
    " 📌 OPERADORES SUPORTADOS:
    "    + → Adição
    "    - → Subtração
    "    * → Multiplicação
    "    / → Divisão
    "    P → Potência (num1 elevado a num2)
    "-------------------------------------------------------------------------
    LOOP AT lt_operations ASSIGNING FIELD-SYMBOL(<operation>).

      TRY.
          "-----------------------------------------------------------------
          " Executa a operação matemática usando SWITCH #( )
          " O resultado é convertido para string automaticamente
          " pelo ABAP (o campo Result é CHAR50)
          "-----------------------------------------------------------------
          <operation>-Result = SWITCH #( <operation>-Operator
            WHEN '+' THEN |{ <operation>-Operand1 + <operation>-Operand2 }|
            WHEN '-' THEN |{ <operation>-Operand1 - <operation>-Operand2 }|
            WHEN '*' THEN |{ <operation>-Operand1 * <operation>-Operand2 }|
            WHEN '/' THEN |{ CONV decfloat34( <operation>-Operand1 ) / <operation>-Operand2 }|
            WHEN 'P' THEN |{ ipow( base = <operation>-Operand1 exp = <operation>-Operand2 ) }|
            ELSE `Operador inválido` ).

          "-----------------------------------------------------------------
          " Tratamento especial: Divisão de 0 por 0
          " ABAP permite 0/0 = 0, mas matematicamente é indefinido.
          " Tratamos explicitamente para feedback claro ao aluno.
          "-----------------------------------------------------------------
          IF <operation>-Operand1 = 0 AND <operation>-Operand2 = 0
             AND <operation>-Operator = '/'.
            <operation>-Result = `Divisão por 0`.
          ENDIF.

        CATCH cx_sy_zerodivide.
          "---------------------------------------------------------------
          " 📌 EXCEÇÃO: cx_sy_zerodivide
          " Disparada quando tentamos dividir um número diferente de
          " zero por zero. ABAP levanta esta exceção de runtime.
          "---------------------------------------------------------------
          <operation>-Result = `Divisão por 0`.

        CATCH cx_sy_arithmetic_overflow.
          "---------------------------------------------------------------
          " 📌 EXCEÇÃO: cx_sy_arithmetic_overflow
          " Disparada quando o resultado excede o limite do tipo
          " numérico (ex: potências muito grandes).
          "---------------------------------------------------------------
          <operation>-Result = `Erro de overflow`.

      ENDTRY.

    ENDLOOP.

    "-------------------------------------------------------------------------
    " PASSO 3: Gravar o resultado calculado de volta na instância
    "
    " 📌 MODIFY ENTITIES OF <bdef> IN LOCAL MODE
    "    - ENTITY Operation = qual entidade modificar
    "    - UPDATE FIELDS ( Result ) = quais campos atualizar
    "    - WITH CORRESPONDING #( lt_operations ) = dados com os valores
    "      atualizados (incluindo o Result que acabamos de calcular)
    "
    "    O framework pega o valor de Result que calculamos acima
    "    e o grava na instância (draft table, se estiver em draft).
    "-------------------------------------------------------------------------
    MODIFY ENTITIES OF zi_calc_operations IN LOCAL MODE
      ENTITY Operation
        UPDATE FIELDS ( Result )
        WITH CORRESPONDING #( lt_operations )
        FAILED DATA(lt_failed_mod)
        REPORTED DATA(lt_reported_mod).

  ENDMETHOD.


  METHOD setAdminFields.
    "=========================================================================
    " 🎓 DETERMINATION: setAdminFields
    "=========================================================================
    "
    " QUANDO EXECUTA: Na criação de uma nova instância.
    "                 (definido no BDEF: determination setAdminFields
    "                  on modify { create; })
    "
    " O QUE FAZ: Preenche os campos CreatedBy e CreatedAt com o
    "            usuário atual e o timestamp atual.
    "
    " 📌 NOTA DIDÁTICA:
    " Em cenários de produção com @Semantics.user.createdBy e
    " @Semantics.systemDateTime.createdAt na CDS, o framework
    " managed PODE preencher automaticamente. Porém, implementamos
    " explicitamente aqui para que os alunos entendam:
    " 1. Como uma determination on create funciona
    " 2. Como usar EML para modificar campos
    " 3. Como obter dados do sistema (sy-uname, utclong_current())
    "=========================================================================

    "-------------------------------------------------------------------------
    " Ler as instâncias recém-criadas
    "-------------------------------------------------------------------------
    READ ENTITIES OF zi_calc_operations IN LOCAL MODE
      ENTITY Operation
        FIELDS ( CreatedBy CreatedAt )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_operations)
        FAILED DATA(lt_failed_read)
        REPORTED DATA(lt_reported_read).

    "-------------------------------------------------------------------------
    " Preparar a lista de atualizações
    "
    " 📌 VALUE #( FOR ... ):
    "    Expressão funcional que itera sobre lt_operations e
    "    cria uma nova tabela com os campos que queremos atualizar.
    "
    " 📌 %tky:
    "    Transactional Key = %key + %is_draft.
    "    SEMPRE use %tky (não %key) para garantir que o framework
    "    manipule corretamente drafts e instâncias ativas.
    "
    " 📌 %control:
    "    Estrutura de controle que indica QUAIS campos estão sendo
    "    atualizados. Apenas campos com %control = if_abap_behv=>mk-on
    "    serão de fato gravados. Isso evita sobrescrever campos
    "    que não pretendemos alterar.
    "-------------------------------------------------------------------------
    DATA lt_update TYPE TABLE FOR UPDATE zi_calc_operations.

    lt_update = VALUE #( FOR ls_op IN lt_operations
      ( %tky          = ls_op-%tky
        CreatedBy     = sy-uname
        CreatedAt     = utclong_current( )
        %control = VALUE #(
          CreatedBy = if_abap_behv=>mk-on
          CreatedAt = if_abap_behv=>mk-on
        )
      )
    ).

    "-------------------------------------------------------------------------
    " Gravar os campos administrativos
    "-------------------------------------------------------------------------
    MODIFY ENTITIES OF zi_calc_operations IN LOCAL MODE
      ENTITY Operation
        UPDATE FROM lt_update
        FAILED DATA(lt_failed_mod)
        REPORTED DATA(lt_reported_mod).

  ENDMETHOD.


  METHOD validateOperands.
    "=========================================================================
    " 🎓 VALIDATION: validateOperands
    "=========================================================================
    "
    " QUANDO EXECUTA: No momento do SAVE (Activate do draft).
    "                 (definido no BDEF: validation validateOperands
    "                  on save { create; field Operand1, Operator, Operand2; })
    "
    " O QUE FAZ: Verifica se os dados inseridos são válidos antes de
    "            permitir a persistência. Se inválidos, popula:
    "            - failed-Operation → marca instância como com erro
    "            - reported-Operation → mensagem de erro para o UI
    "
    " 📌 DIFERENÇA FUNDAMENTAL:
    "    - Determination → CALCULA valor (campo Result)
    "    - Validation → VERIFICA valor (e rejeita se inválido)
    "
    " 📌 A validation NÃO impede a determination de rodar.
    "    A determination roda durante a edição (on modify).
    "    A validation roda no save. Ambas coexistem.
    "
    " 📌 draft determine action Prepare { validation validateOperands; }
    "    No BDEF, declaramos que o Prepare deve executar esta validation.
    "    Isso significa que quando o Fiori chama "Prepare" (antes do
    "    Save/Activate), esta validation é executada e os erros são
    "    mostrados antes de tentar ativar.
    "=========================================================================

    "-------------------------------------------------------------------------
    " Ler os dados das instâncias que serão validadas
    "-------------------------------------------------------------------------
    READ ENTITIES OF zi_calc_operations IN LOCAL MODE
      ENTITY Operation
        FIELDS ( Operand1 Operator Operand2 Result )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_operations)
        FAILED DATA(lt_failed_read)
        REPORTED DATA(lt_reported_read).

    "-------------------------------------------------------------------------
    " Validar cada instância
    "-------------------------------------------------------------------------
    LOOP AT lt_operations ASSIGNING FIELD-SYMBOL(<operation>).

      "-----------------------------------------------------------------
      " Limpar o estado de validação para esta instância
      "
      " 📌 %state_area:
      "    Agrupa mensagens de validação. Quando a validação roda
      "    novamente, o framework limpa as mensagens antigas do
      "    mesmo state_area antes de adicionar as novas.
      "-----------------------------------------------------------------
      APPEND VALUE #(
        %tky        = <operation>-%tky
        %state_area = 'VALIDATE_OPERANDS'
      ) TO reported-Operation.


      "-----------------------------------------------------------------
      " VALIDAÇÃO 1: Operador deve ser +, -, *, / ou P
      "
      " 📌 NOT ... IN ...
      "    Verifica se o valor NÃO está na lista de valores válidos.
      "    Usamos VALUE # com multiple entries para criar a lista inline.
      "-----------------------------------------------------------------
      IF <operation>-Operator <> '+' AND <operation>-Operator <> '-'
         AND <operation>-Operator <> '*' AND <operation>-Operator <> '/'
         AND <operation>-Operator <> 'P'.

        "---------------------------------------------------------------
        " Marcar instância como FALHADA
        "
        " 📌 failed-Operation:
        "    Tabela implícita. Ao adicionar %tky aqui, o framework
        "    sabe que esta instância TEM ERRO e impede o save.
        "---------------------------------------------------------------
        APPEND VALUE #( %tky = <operation>-%tky ) TO failed-Operation.

        "---------------------------------------------------------------
        " Adicionar MENSAGEM DE ERRO
        "
        " 📌 reported-Operation:
        "    Tabela implícita. Contém as mensagens exibidas no UI.
        "
        " 📌 new_message_with_text():
        "    Método helper de cl_abap_behavior_handler que cria
        "    uma mensagem de erro simples (sem message class).
        "    Em produção, use message classes para i18n.
        "
        " 📌 %element-Operator:
        "    Destaca (highlight) o campo Operator no UI para mostrar
        "    ao usuário exatamente QUAL campo tem o problema.
        "    if_abap_behv=>mk-on = "ativado"
        "---------------------------------------------------------------
        APPEND VALUE #(
          %tky        = <operation>-%tky
          %state_area = 'VALIDATE_OPERANDS'
          %msg        = new_message_with_text(
            text     = 'Operador inválido! Use: + - * / P'
            severity = if_abap_behv_message=>severity-error )
          %element-Operator = if_abap_behv=>mk-on
        ) TO reported-Operation.

      "-----------------------------------------------------------------
      " VALIDAÇÃO 2: Divisão por zero
      "-----------------------------------------------------------------
      ELSEIF <operation>-Result = 'Divisão por 0'.

        APPEND VALUE #( %tky = <operation>-%tky ) TO failed-Operation.

        APPEND VALUE #(
          %tky        = <operation>-%tky
          %state_area = 'VALIDATE_OPERANDS'
          %msg        = new_message_with_text(
            text     = 'Divisão por zero não é permitida!'
            severity = if_abap_behv_message=>severity-error )
          %element-Operator = if_abap_behv=>mk-on
          %element-Operand2 = if_abap_behv=>mk-on
        ) TO reported-Operation.

      "-----------------------------------------------------------------
      " VALIDAÇÃO 3: Overflow aritmético
      "-----------------------------------------------------------------
      ELSEIF <operation>-Result = 'Erro de overflow'.

        APPEND VALUE #( %tky = <operation>-%tky ) TO failed-Operation.

        APPEND VALUE #(
          %tky        = <operation>-%tky
          %state_area = 'VALIDATE_OPERANDS'
          %msg        = new_message_with_text(
            text     = 'Overflow! Use números menores.'
            severity = if_abap_behv_message=>severity-error )
          %element-Operand1 = if_abap_behv=>mk-on
          %element-Operand2 = if_abap_behv=>mk-on
        ) TO reported-Operation.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_global_authorizations.
    "=========================================================================
    " 🎓 AUTHORIZATION: get_global_authorizations
    "=========================================================================
    "
    " 📌 Este método é obrigatório quando o BDEF declara:
    "    "authorization master ( global )"
    "
    " Em um cenário de produção, aqui você verificaria o
    " authorization object (AUTHORITY-CHECK OBJECT) para decidir
    " se o usuário pode criar, atualizar ou deletar.
    "
    " Para fins didáticos, deixamos sem implementação, o que
    " significa que TODOS os usuários têm acesso completo.
    "
    " 📌 Em produção, NUNCA deixe vazio! Exemplo:
    "    AUTHORITY-CHECK OBJECT 'Z_CALC_AUTH'
    "      ID 'ACTVT' FIELD '02'.
    "    IF sy-subrc <> 0.
    "      result-%update = if_abap_behv=>auth-unauthorized.
    "    ENDIF.
    "=========================================================================
  ENDMETHOD.

ENDCLASS.


***********************************************************************
*  ═══════════════════════════════════════════════════════════════════
*   SAVER CLASS: lsc_zi_calc_operations
*  ═══════════════════════════════════════════════════════════════════
*
*  🎓 CONCEITO DIDÁTICO: O que é a Saver Class?
*  ─────────────────────────────────────────────
*  A Saver Class herda de CL_ABAP_BEHAVIOR_SAVER e implementa
*  métodos que rodam NO MOMENTO DO SAVE (commit work).
*
*  Diferente da Handler Class (que roda durante a interação),
*  a Saver Class roda APENAS quando os dados são de fato
*  persistidos no banco de dados.
*
*  📌 MÉTODOS DISPONÍVEIS:
*
*  1. adjust_numbers → Atribui chaves finais (late numbering)
*     Roda ANTES do save. Aqui convertemos %pid em %key.
*
*  2. save_modified → Lógica adicional no save
*     Roda DURANTE o save. Aqui criamos o registro de histórico.
*     Temos acesso a CREATE/UPDATE/DELETE para ver quais instâncias
*     estão sendo criadas/modificadas/deletadas.
*
*  3. cleanup_finalize → Limpeza final (raramente usado)
*
*  📌 POR QUE adjust_numbers É IMPORTANTE?
*  No RAP com late numbering, quando o usuário cria uma instância,
*  ela ainda não tem a chave real (UUID). O framework atribui um
*  %pid (provisional ID) temporário. No adjust_numbers, devemos
*  mapear %pid → %key para que o framework saiba a chave final.
*
***********************************************************************
CLASS lsc_zi_calc_operations DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS adjust_numbers REDEFINITION.
    METHODS save_modified  REDEFINITION.

ENDCLASS.


CLASS lsc_zi_calc_operations IMPLEMENTATION.

  METHOD adjust_numbers.
    "=========================================================================
    " 🎓 LATE NUMBERING: adjust_numbers
    "=========================================================================
    "
    " QUANDO EXECUTA: Logo antes do COMMIT WORK, após todas as
    "                 validations e determinations terem rodado.
    "
    " O QUE FAZ: Atribui a chave FINAL (UUID) a cada instância nova.
    "
    " 📌 COMO FUNCIONA:
    " 1. O framework cria instâncias com %pid (ID provisório)
    " 2. Neste método, iteramos sobre mapped-Operation
    "    (tabela com as instâncias que serão salvas)
    " 3. Para cada uma, configuramos %key-CalcUuid = %pid
    "    (neste caso simplificado, %pid já é um UUID válido)
    "
    " 📌 ALTERNATIVA: EARLY NUMBERING
    "    Se usássemos "early numbering" no BDEF, a chave seria
    "    atribuída NO MOMENTO DA CRIAÇÃO (antes de qualquer edição).
    "    Isso requer implementar o método FOR NUMBERING.
    "    Late numbering é mais comum em cenários com draft.
    "
    " 📌 %pid vs %key:
    "    - %pid = Provisional ID (temporário, usado durante o ciclo)
    "    - %key = Chave real da entidade (usada na tabela de banco)
    "    Neste ponto, precisamos mapear um para o outro.
    "=========================================================================

    "-------------------------------------------------------------------------
    " Atribuir UUID para cada nova Operation
    "-------------------------------------------------------------------------
    LOOP AT mapped-Operation ASSIGNING FIELD-SYMBOL(<operation>).
      <operation>-%key-CalcUuid = <operation>-%pid.
    ENDLOOP.

    "-------------------------------------------------------------------------
    " Atribuir UUID para cada novo History
    "
    " 📌 Registros de History são criados no save_modified.
    "    Mas se por algum motivo existirem instâncias de History
    "    em mapped, também precisamos atribuir a chave.
    "-------------------------------------------------------------------------
    LOOP AT mapped-History ASSIGNING FIELD-SYMBOL(<history>).
      <history>-%key-HistUuid = <history>-%pid.
    ENDLOOP.

  ENDMETHOD.


  METHOD save_modified.
    "=========================================================================
    " 🎓 ADDITIONAL SAVE: save_modified
    "=========================================================================
    "
    " QUANDO EXECUTA: Durante o COMMIT WORK, após adjust_numbers.
    "
    " O QUE FAZ: Cria um registro de HISTÓRICO para cada operação
    "            que está sendo criada ou atualizada.
    "
    " 📌 CONCEITO: ADDITIONAL SAVE
    "    O framework managed já faz o INSERT/UPDATE/DELETE das
    "    entidades automaticamente. Este método serve para
    "    executar lógica ADICIONAL durante o save.
    "
    "    No nosso caso: quando uma Operation é salva (criada ou
    "    atualizada), queremos criar um snapshot no histórico.
    "
    " 📌 CHANGING PARAMETER create:
    "    Contém as instâncias que estão sendo CRIADAS.
    "    create-Operation = tabela com dados das novas operações.
    "
    " 📌 CHANGING PARAMETER update:
    "    Contém as instâncias que estão sendo ATUALIZADAS.
    "    update-Operation = tabela com dados das operações modificadas.
    "
    " 📌 NOTA SOBRE DRAFT:
    "    O save_modified roda quando o draft é ATIVADO (não quando
    "    o draft é salvo). Ou seja, os dados do draft table são
    "    movidos para a tabela persistente, e ENTÃO este método roda.
    "=========================================================================

    "-------------------------------------------------------------------------
    " Coletar todas as operações que estão sendo salvas
    " (tanto criações quanto atualizações)
    "-------------------------------------------------------------------------
    DATA lt_history TYPE TABLE OF zcalc_history.

    "-------------------------------------------------------------------------
    " Processar CRIAÇÕES
    "
    " 📌 create-Operation é uma tabela com todos os dados
    "    das instâncias de Operation sendo criadas neste save.
    "    Iteramos para criar um registro de histórico para cada.
    "-------------------------------------------------------------------------
    IF create-Operation IS NOT INITIAL.
      LOOP AT create-Operation ASSIGNING FIELD-SYMBOL(<create>).

        "-------------------------------------------------------------------
        " Gerar novo UUID para o registro de histórico
        "
        " 📌 cl_system_uuid=>create_uuid_x16_static()
        "    Gera um UUID v4 de 16 bytes. Este é o método padrão
        "    recomendado pela SAP para gerar UUIDs em ABAP Cloud.
        "-------------------------------------------------------------------
        TRY.
            DATA(lv_hist_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.
            CONTINUE.
        ENDTRY.

        APPEND VALUE #(
          hist_uuid   = lv_hist_uuid
          calc_uuid   = <create>-CalcUuid
          operand_1   = <create>-Operand1
          operator    = <create>-Operator
          operand_2   = <create>-Operand2
          result      = <create>-Result
          executed_by = sy-uname
          executed_at = utclong_current( )
          local_last_changed_at = utclong_current( )
        ) TO lt_history.

      ENDLOOP.
    ENDIF.

    "-------------------------------------------------------------------------
    " Processar ATUALIZAÇÕES
    "
    " 📌 update-Operation contém as instâncias modificadas.
    "    Quando o usuário edita uma operação e salva novamente,
    "    criamos mais um registro de histórico com os valores atuais.
    "    Isso garante um log completo de toda atividade.
    "-------------------------------------------------------------------------
    IF update-Operation IS NOT INITIAL.

      "---------------------------------------------------------------------
      " Para updates, precisamos ler os dados completos da instância,
      " pois update-Operation pode conter apenas os campos modificados.
      "---------------------------------------------------------------------
      DATA lt_calc_uuids TYPE TABLE OF sysuuid_x16.
      lt_calc_uuids = VALUE #( FOR ls_upd IN update-Operation
                                 ( ls_upd-CalcUuid ) ).

      "---------------------------------------------------------------------
      " Ler os dados completos diretamente da tabela persistente
      " (neste ponto do save, os dados já foram gravados pelo framework)
      "---------------------------------------------------------------------
      IF lt_calc_uuids IS NOT INITIAL.
        SELECT calc_uuid, operand_1, operator, operand_2, result
          FROM zcalc_operations
          FOR ALL ENTRIES IN @lt_calc_uuids
          WHERE calc_uuid = @lt_calc_uuids-table_line
          INTO TABLE @DATA(lt_updated_ops).

        LOOP AT lt_updated_ops ASSIGNING FIELD-SYMBOL(<updated>).

          TRY.
              lv_hist_uuid = cl_system_uuid=>create_uuid_x16_static( ).
            CATCH cx_uuid_error.
              CONTINUE.
          ENDTRY.

          APPEND VALUE #(
            hist_uuid   = lv_hist_uuid
            calc_uuid   = <updated>-calc_uuid
            operand_1   = <updated>-operand_1
            operator    = <updated>-operator
            operand_2   = <updated>-operand_2
            result      = <updated>-result
            executed_by = sy-uname
            executed_at = utclong_current( )
            local_last_changed_at = utclong_current( )
          ) TO lt_history.

        ENDLOOP.
      ENDIF.
    ENDIF.

    "-------------------------------------------------------------------------
    " Inserir todos os registros de histórico de uma vez
    "
    " 📌 INSERT ... FROM TABLE:
    "    Insere múltiplas linhas de uma vez (bulk insert).
    "    Mais performático do que inserir uma a uma em loop.
    "
    " 📌 NOTA CLEAN CORE:
    "    Normalmente, no Clean Core estrito, evitamos SQL direto.
    "    Porém, no save_modified do managed RAP, é ACEITÁVEL
    "    fazer INSERT em tabelas auxiliares porque estamos dentro
    "    do ciclo de save controlado pelo framework.
    "    A alternativa seria usar EML com MODIFY ENTITIES, mas
    "    no save_modified isso não é possível para a mesma entidade
    "    (pois já estamos dentro do save cycle).
    "-------------------------------------------------------------------------
    IF lt_history IS NOT INITIAL.
      INSERT zcalc_history FROM TABLE @lt_history.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
