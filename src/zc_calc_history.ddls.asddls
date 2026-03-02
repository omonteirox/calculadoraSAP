///////////////////////////////////////////////////////////////////////////////
// =====================================================================
//  CDS VIEW: ZC_CALC_History (Projection Layer - Consumption)
// =====================================================================
//
//  🎓 CONCEITO DIDÁTICO: Projeção de Entidade Filha
//  ─────────────────────────────────────────────────
//  Assim como o pai tem sua projeção, cada entidade filha na
//  composição também precisa de uma Projection View correspondente.
//
//  📌 REDIRECTED TO:
//  - Na projeção do pai, escrevemos:
//    _History : redirected to composition child ZC_CALC_History
//  - Na projeção do filho, escrevemos:
//    _Operation : redirected to parent ZC_CALC_Operations
//  - Isso "reconecta" as associações na camada de projeção,
//    garantindo que o framework navegue corretamente.
//
///////////////////////////////////////////////////////////////////////////////

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculadora RAP - Histórico (Projection)'

@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['HistUuid']

define view entity ZC_CALC_History
  as projection on ZI_CALC_History

{
  key HistUuid,

      CalcUuid,

      ///////////////////////////////////////////////////////////////////////
      // SNAPSHOT DA OPERAÇÃO (campos de auditoria)
      // - Estes valores são imutáveis: representam o estado exato
      //   no momento em que a operação foi salva/ativada
      ///////////////////////////////////////////////////////////////////////
      Operand1,
      Operator,
      Operand2,
      CalcResult,

      ExecutedBy,
      ExecutedAt,
      LocalLastChangedAt,

      ///////////////////////////////////////////////////////////////////////
      // ASSOCIAÇÃO AO PAI RE-DIRECIONADA
      // - "redirected to parent" reconecta a associação para a
      //   Projection View do pai (ZC_CALC_Operations)
      ///////////////////////////////////////////////////////////////////////
      //_Operation : redirected to parent ZC_CALC_Operations
}
