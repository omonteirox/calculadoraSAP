///////////////////////////////////////////////////////////////////////////////
// =====================================================================
//  CDS VIEW: ZC_CALC_Operations (Projection Layer - Consumption)
// =====================================================================
//
//  🎓 CONCEITO DIDÁTICO: CDS Projection View (prefixo "C_")
//  ──────────────────────────────────────────────────────────
//  A Projection View é a camada de CONSUMO do modelo RAP.
//  Ela projeta (seleciona) campos da Interface View e define
//  COMO os dados serão expostos para o consumidor (UI, API, etc).
//
//  📌 POR QUE DUAS CAMADAS?
//  - Interface View (I_): define o modelo de dados COMPLETO
//  - Projection View (C_): define o que cada CONSUMIDOR vê
//  - Exemplo: a mesma Interface View pode ter uma projeção para
//    o app Fiori (com todos os campos) e outra para uma API
//    externa (com campos reduzidos e sem draft).
//
//  📌 provider contract transactional_query:
//  - Indica que esta projeção suporta operações transacionais
//    (criar, editar, deletar via RAP)
//  - É obrigatório quando a projeção é usada com BDEF de projeção
//
//  📌 REGRA CLEAN CORE:
//  - Projeções NUNCA acessam tabelas diretamente
//  - Projeções SEMPRE projetam de uma Interface View
//  - Projeções podem adicionar anotações específicas do consumidor
//
///////////////////////////////////////////////////////////////////////////////

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculadora RAP - Operações (Projection)'

@Metadata.allowExtensions: true

define root view entity ZC_CALC_Operations
  provider contract transactional_query
  as projection on ZI_CALC_Operations

{
      ///////////////////////////////////////////////////////////////////////
      // 📌 NOTA: Na projeção, simplesmente re-expomos os campos da
      //    Interface View. Podemos:
      //    - Omitir campos (se não quisermos expor para este consumidor)
      //    - Adicionar alias diferentes
      //    - Adicionar anotações específicas via @ObjectModel, @Search, etc.
      //
      //    As anotações de UI (@UI.lineItem, @UI.identification, etc.)
      //    ficam na METADATA EXTENSION separada, seguindo best practice.
      ///////////////////////////////////////////////////////////////////////

      @ObjectModel.semanticKey: ['CalcUuid']
  key CalcUuid,

      Operand1,
      Operator,
      Operand2,
      Result,

      ///////////////////////////////////////////////////////////////////////
      // CAMPOS ADMINISTRATIVOS
      // - Re-expostos aqui para que o Fiori Elements possa exibi-los
      // - As anotações @Semantics já foram definidas na Interface View
      //   e são HERDADAS automaticamente pela Projection
      ///////////////////////////////////////////////////////////////////////
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      ///////////////////////////////////////////////////////////////////////
      // COMPOSIÇÃO RE-EXPOSTA
      // - Obrigatório re-expor a composição na Projection View
      // - O Fiori Elements usa isso para gerar a navegação entre
      //   a Object Page do pai e a tabela de filhos
      ///////////////////////////////////////////////////////////////////////
      /* Composition: re-expose */
      _History : redirected to composition child ZC_CALC_History
}
