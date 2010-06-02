// CORE module, abstracts environment-specifics
var CORE = function(){

    /*
     * blatantly ripped off from Douglas Crockford
     */
    var modifyLanguage = function(){
        Function.prototype.method = function (name, func) {
            if (!this.prototype[name]){
                this.prototype[name] = func;
                return this;
            }
        };

        Array.method('each', function(f, index){
            for (var i=0; i<this.length; i++){
                f(this[i], i);
            }
        });

        Array.method('reduce', function(f, value){
            this.each(function(item){
                value = f(item, value);
            });
            return value;
        });
        Array.method('contains', function(test){
            var contains = false;
            this.each(function(item){
                if (item === test){
                    contains = true;
                    return false;
                }
            });
            return contains;
        });
    };

    modifyLanguage();

    return {

        out : function(output){
            //implemented by env
        },

        require : function(toImport){
            this.out("'require' not implemented!");
        }
    };
}();