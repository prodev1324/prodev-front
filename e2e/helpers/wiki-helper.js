var utils = require('../utils');

var helper = module.exports;

helper.links = function() {
    let el = $('section[tg-wiki-nav]');

    let obj = {
        el: el,

        addLink: async function(pageTitle){
            el.$(".add-button").click();
            el.$(".new input").sendKeys(pageTitle);
            browser.actions().sendKeys(protractor.Key.ENTER).perform();
            await browser.waitForAngular();
            let newLink = await el.$$(".wiki-link a").last();
            return newLink;
        },

        get: function() {
            return el.$$(".wiki-link a");
        },

        deleteLink: async function(link){
            link.$(".icon-trash").click();
            await utils.lightbox.confirm.ok();
            await browser.waitForAngular();
        }

    };

    return obj;
};

helper.editor = function(){
    let el = $('.main.wiki');

    let obj = {
        el: el,

        enabledEditionMode: async function(){
            await el.$("section[tg-editable-wiki-content] .view-wiki-content").click();
        },

        getTimesEdited: async function(){
            let total = await el.$(".wiki-times-edited .number").getText();
            return total;
        },

        getLastEditionDateTime: async function(){
            let date = await el.$(".wiki-last-modified .number").getText();
            return date;
        },

        getLastEditor: async function(){
            let editor = await el.$(".wiki-user-modification .username").getText();
            return editor;
        },

        getInnerHtml: async function(text){
            let wikiText = await el.$(".content").getInnerHtml();
            return wikiText;
        },

        getText: async function(text){
            let wikiText = await el.$("textarea").getAttribute('value');
            return wikiText;
        },

        setText: async function(text){
            await el.$("textarea").clear().sendKeys(text);
        },

        preview: async function(){
            await el.$(".preview-icon a").click();
            await browser.waitForAngular();
        },

        save: async function(){
            await el.$(".save").click();
            await browser.waitForAngular();
        },

        delete: async function(){
            await el.$('.remove').click();
            await utils.lightbox.confirm.ok();
            await browser.waitForAngular();
        }

    };

    return obj;
};
