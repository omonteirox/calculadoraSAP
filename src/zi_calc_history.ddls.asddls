///////////////////////////////////////////////////////////////////////////////
// =====================================================================
//  CDS VIEW: ZI_CALC_History (Interface Layer - Entidade Filha)
// =====================================================================
//
//  🎓 CONCEITO DIDÁTICO: Entidade Filha em Composição RAP
//  ────────────────────────────────────────────────────────
//  Esta view representa o HISTÓRICO de operações da calculadora.
//  Ela é uma entidade FILHA (child) da entidade raiz ZI_CALC_Operations.
//
//  📌 DIFERENÇAS entre Root e Child:
//  - Root usa "define root view entity"
//  - Child usa "define view entity" (sem "root")
//  - Child tem "association to parent" apontando para o pai
//  - No BDEF, child terá "lock dependent" e "authorization dependent"
//
//  📌 POR QUE TER UM HISTÓRICO SEPARADO?
//  - A tabela de operações (pai) representa o ESTADO ATUAL da operação
//  - O histórico (filho) é um LOG IMUTÁVEL de todas as vezes que aquela
//    operação foi calculada e salva
//  - Isso ensina o conceito de composição e também boas práticas de
//    auditoria em sistemas empresariais
//
///////////////////////////////////////////////////////////////////////////////

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculadora RAP - Histórico (Interface)'

define view entity ZI_CALC_History
  as select from zcalc_history

  ///////////////////////////////////////////////////////////////////////
  // ASSOCIAÇÃO AO PAI (Parent Association)
  // - "association to parent" indica que esta entidade é FILHA
  // - A condição ON mapeia a foreign key (calc_uuid) com a chave do pai
  // - O framework RAP usa isso para:
  //   1. Determinar a hierarquia de lock (quem trava quem)
  //   2. Cascade delete (se o pai for deletado, filhos também são)
  //   3. Navegação OData (expand/associação)
  ///////////////////////////////////////////////////////////////////////
  association to parent ZI_CALC_Operations as _Operation
    on $projection.CalcUuid = _Operation.CalcUuid

{
      ///////////////////////////////////////////////////////////////////////
      // CHAVE PRIMÁRIA DO HISTÓRICO
      // - Cada registro de histórico tem seu próprio UUID
      // - Isso permite múltiplos registros de histórico para a mesma operação
      ///////////////////////////////////////////////////////////////////////
  key hist_uuid        as HistUuid,

      ///////////////////////////////////////////////////////////////////////
      // FOREIGN KEY → Pai (Operação)
      // - calc_uuid liga este registro ao pai
      // - No RAP com composição, este campo é preenchido automaticamente
      //   pelo framework quando criamos um filho via EML
      ///////////////////////////////////////////////////////////////////////
      calc_uuid        as CalcUuid,

      ///////////////////////////////////////////////////////////////////////
      // SNAPSHOT DA OPERAÇÃO
      // - Estes campos são uma CÓPIA dos valores no momento do cálculo
      // - Mesmo que o usuário altere a operação depois, o histórico
      //   preserva os valores originais (princípio de imutabilidade)
      ///////////////////////////////////////////////////////////////////////
      operand_1        as Operand1,
      operator         as Operator,
      operand_2        as Operand2,
      calc_result      as CalcResult,

      ///////////////////////////////////////////////////////////////////////
      // CAMPOS DE AUDITORIA DO HISTÓRICO
      ///////////////////////////////////////////////////////////////////////
      @Semantics.user.createdBy: true
      executed_by      as ExecutedBy,

      @Semantics.systemDateTime.createdAt: true
      executed_at      as ExecutedAt,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      ///////////////////////////////////////////////////////////////////////
      // ASSOCIAÇÃO AO PAI (re-exposição obrigatória)
      ///////////////////////////////////////////////////////////////////////
      _Operation
}
