///////////////////////////////////////////////////////////////////////////////
// =====================================================================
//  CDS VIEW: ZI_CALC_Operations (Interface Layer - Entidade Raiz)
// =====================================================================
//
//  🎓 CONCEITO DIDÁTICO: CDS View de Interface (prefixo "I_")
//  ─────────────────────────────────────────────────────────────
//  No modelo RAP em 2 camadas (Interface + Projection), a view de
//  Interface é a camada que define o MODELO DE DADOS SEMÂNTICO.
//  Ela fica diretamente sobre a tabela de banco de dados e é
//  responsável por:
//
//  1. Mapear os campos da tabela para nomes CamelCase legíveis
//  2. Definir associações e composições (relacionamentos)
//  3. Aplicar anotações semânticas (@Semantics)
//  4. NÃO conter anotações de UI (essas ficam na Metadata Extension)
//
//  📌 REGRA CLEAN CORE:
//  - Usar @AccessControl.authorizationCheck: #NOT_REQUIRED
//    quando não há CDS Access Control definido (cenário didático).
//  - Em produção, SEMPRE definir DCL (Data Control Language).
//
//  📌 COMPOSIÇÃO (composition):
//  - A keyword "composition [0..*] of" define que ZI_CALC_History
//    é uma entidade FILHA desta entidade raiz.
//  - Isso cria um relacionamento pai-filho no RAP, onde o filho
//    depende do pai para lock, authorization e ciclo de vida.
//
///////////////////////////////////////////////////////////////////////////////

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculadora RAP - Operações (Interface)'

define root view entity ZI_CALC_Operations
  as select from zcalc_operations

  ///////////////////////////////////////////////////////////////////////
  // COMPOSIÇÃO: Define que "History" é entidade filha de "Operation"
  // No RAP, composição significa que:
  //   - O filho herda o lock do pai (lock dependent)
  //   - O filho herda a autorização do pai (authorization dependent)
  //   - O ciclo de vida do filho está atrelado ao pai
  ///////////////////////////////////////////////////////////////////////
  composition [0..*] of ZI_CALC_History as _History

{
      ///////////////////////////////////////////////////////////////////////
      // CHAVE PRIMÁRIA
      // - "key" define o campo como parte da chave da view entity
      // - SYSUUID_X16 = UUID de 16 bytes, formato hexadecimal
      // - No RAP managed, o framework pode gerar o UUID automaticamente
      //   (early numbering) ou o desenvolvedor atribui (late numbering)
      ///////////////////////////////////////////////////////////////////////
  key calc_uuid       as CalcUuid,

      ///////////////////////////////////////////////////////////////////////
      // CAMPOS DE NEGÓCIO (Business Fields)
      // - São os campos que o usuário preenche na tela
      // - O mapeamento "campo_tabela as NomeCamelCase" é obrigatório
      //   em CDS view entities (não confundir com CDS views clássicas)
      ///////////////////////////////////////////////////////////////////////
      operand_1        as Operand1,
      operator         as Operator,
      operand_2        as Operand2,
      calc_result      as CalcResult,

      ///////////////////////////////////////////////////////////////////////
      // CAMPOS ADMINISTRATIVOS (Admin Fields)
      //
      // 🎓 CONCEITO: Estes campos são preenchidos AUTOMATICAMENTE pelo
      //    framework RAP quando usamos as anotações @Semantics corretas.
      //    O framework sabe que:
      //    - @Semantics.user.createdBy → preencher com sy-uname na criação
      //    - @Semantics.systemDateTime.createdAt → preencher com timestamp
      //    - @Semantics.user.lastChangedBy → atualizar a cada modificação
      //    - @Semantics.systemDateTime.lastChangedAt → ETag global
      //    - @Semantics.systemDateTime.localInstanceLastChangedAt → ETag local
      //
      // 📌 ETag (Entity Tag):
      //    Mecanismo de controle de concorrência otimista.
      //    O framework compara o ETag do cliente com o do servidor
      //    antes de permitir uma atualização. Se forem diferentes,
      //    significa que outro usuário já alterou o registro.
      //
      //    - "total etag" = usado para detectar mudanças entre draft e ativo
      //    - "etag master" = ETag principal para controle de concorrência
      ///////////////////////////////////////////////////////////////////////

      @Semantics.user.createdBy: true
      created_by       as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at       as CreatedAt,

      @Semantics.user.lastChangedBy: true
      last_changed_by  as LastChangedBy,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at  as LastChangedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      ///////////////////////////////////////////////////////////////////////
      // ASSOCIAÇÃO DE COMPOSIÇÃO (re-exposição obrigatória)
      // - Toda composição declarada no "as select from" DEVE ser
      //   re-exposta na lista de campos com o prefixo "_"
      // - Isso permite que o framework RAP navegue do pai para o filho
      ///////////////////////////////////////////////////////////////////////
      _History
}
