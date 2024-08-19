module.exports = {
  Counter: function Counter(init = 0) {
    return {
      counter: init,
      increment() {
        this.counter++;
        return this.counter;
      },
    };
  },
};
