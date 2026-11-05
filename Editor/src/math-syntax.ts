import {math} from 'micromark-extension-math';
import type {Construct, Extension, State, Tokenizer} from 'micromark-util-types';

// Bloct accepts $$TeX...TeX$$ even when the delimiters share their lines
// with TeX. The upstream flow grammar treats the opening line as metadata
// and only closes on a delimiter-only line. Keep parsing in micromark so code,
// container prefixes, source offsets and blank-line protection remain intact.
const tokenize: Tokenizer = function(effects, ok, nok) {
  let size = 0, valueOpen = false, escaped = false, adjacentText = false;
  const eol = (code: number | null) => code === -5 || code === -4 || code === -3;
  const endValue = () => {if(valueOpen){effects.exit('mathFlowValue');valueOpen=false;}};
  const finish: State = code => {endValue();effects.exit('mathFlow');return ok(code);};
  const closing: Construct = {partial:true, tokenize(closeEffects,yes,no) {
    let count=0;
    closeEffects.enter('mathFlowFence');closeEffects.enter('mathFlowFenceSequence');
    const sequence: State = code => {
      if(code===36){count++;closeEffects.consume(code);return sequence;}
      if(count<size)return no(code);
      closeEffects.exit('mathFlowFenceSequence');
      return after(code);
    };
    const after: State = code => {
      if(code===32||code===-2||code===-1){closeEffects.consume(code);return after;}
      if(code===null||eol(code)){closeEffects.exit('mathFlowFence');return yes(code);}
      adjacentText=true;return no(code);
    };
    return sequence;
  }};
  const data: State = code => {
    if(!valueOpen){effects.enter('mathFlowValue');valueOpen=true;}
    effects.consume(code!);escaped=code===92 ? !escaped : false;return body;
  };
  const body: State = code => {
    if(code===null)return finish(code);
    if(eol(code)) {
      endValue();effects.enter('lineEnding');effects.consume(code!);effects.exit('lineEnding');escaped=false;return body;
    }
    if(code===36&&!escaped) {
      endValue();adjacentText=false;
      return effects.attempt(closing,finish,next=>adjacentText?nok(next):data(next))(code);
    }
    return data(code);
  };
  const opening: State = code => {
    if(code===36){size++;effects.consume(code);return opening;}
    if(size<2)return nok(code);
    effects.exit('mathFlowFenceSequence');effects.exit('mathFlowFence');
    if(this.interrupt)return ok(code);
    return body(code);
  };
  effects.enter('mathFlow');effects.enter('mathFlowFence');effects.enter('mathFlowFenceSequence');
  return opening;
};

export function bloctMath(): Extension {
  const extension=math();
  return {...extension,flow:{36:{tokenize,concrete:true,name:'bloctMathFlow'}}};
}
