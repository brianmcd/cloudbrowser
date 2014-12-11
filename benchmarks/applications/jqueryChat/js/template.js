(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['alertItem.tmpl'] = template({"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  var helper, functionType="function", helperMissing=helpers.helperMissing, escapeExpression=this.escapeExpression;
  return "<div class=\"alert alert-warning alert-dismissible\" id=\"alertMsgItem"
    + escapeExpression(((helper = (helper = helpers.id || (depth0 != null ? depth0.id : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"id","hash":{},"data":data}) : helper)))
    + "\">\n    <button type=\"button\" class=\"close\" onclick=\"removeAlert("
    + escapeExpression(((helper = (helper = helpers.id || (depth0 != null ? depth0.id : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"id","hash":{},"data":data}) : helper)))
    + ")\">\n        <span aria-hidden=\"true\">&times;</span><span class=\"sr-only\">Close</span>\n    </button>\n    "
    + escapeExpression(((helper = (helper = helpers.msg || (depth0 != null ? depth0.msg : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"msg","hash":{},"data":data}) : helper)))
    + "\n</div>";
},"useData":true});
templates['messageItem.tmpl'] = template({"compiler":[6,">= 2.0.0-beta.1"],"main":function(depth0,helpers,partials,data) {
  var stack1, helper, helperMissing=helpers.helperMissing, functionType="function", escapeExpression=this.escapeExpression, buffer = "<div ";
  stack1 = ((helpers['msg-class'] || (depth0 && depth0['msg-class']) || helperMissing).call(depth0, (depth0 != null ? depth0.type : depth0), {"name":"msg-class","hash":{},"data":data}));
  if (stack1 != null) { buffer += stack1; }
  return buffer + ">\n    "
    + escapeExpression(((helper = (helper = helpers.userName || (depth0 != null ? depth0.userName : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"userName","hash":{},"data":data}) : helper)))
    + " : "
    + escapeExpression(((helper = (helper = helpers.msg || (depth0 != null ? depth0.msg : depth0)) != null ? helper : helperMissing),(typeof helper === functionType ? helper.call(depth0, {"name":"msg","hash":{},"data":data}) : helper)))
    + " <span class=\"small\">"
    + escapeExpression(((helpers['format-date'] || (depth0 && depth0['format-date']) || helperMissing).call(depth0, (depth0 != null ? depth0.time : depth0), {"name":"format-date","hash":{},"data":data})))
    + "</span>\n</div>";
},"useData":true});
})();
