module AZBlob
  class Pager(T)
    include Iterator(T)

    @more : Proc(T, Bool)
    @value : T?

    def initialize(@more, &@fetch : T? -> T)
    end

    def next
      if val = @value
        return stop unless @more.call(val)
        ret = @fetch.call(val)
        @value = ret
        return ret
      end
      @value = @fetch.call(nil)
    end
  end
end
