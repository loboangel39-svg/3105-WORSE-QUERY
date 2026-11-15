"""Normalize only the explicitly permitted native presentation literal changes."""
import re
def normalized(text):
 text=re.sub(r'\[UIColor colorWithRed:[0-9.]+ green:[0-9.]+ blue:[0-9.]+ alpha:[0-9.]+\]', '@COLOR_LITERAL', text)
 text=text.replace('self.layer.cornerRadius = MIN(radius, 16.0);', 'self.layer.cornerRadius = radius;')
 text=text.replace('        _effect.alpha = 0.12;\n','')
 text=text.replace('    self.backgroundColor = dark ? @COLOR_LITERAL : UIColor.whiteColor;\n','')
 return text
